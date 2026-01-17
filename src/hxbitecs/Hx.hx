package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import hxbitecs.MacroDebug;

typedef InitializationData = {
    fieldValues:Map<String, Expr>,
    hasValues:Bool
}
#end

/**
 * Main HxBitECS utility class providing macro-powered wrapper functions.
 */
class Hx {

    /**
     * Expression macro for ad-hoc queries that use bitecs.Bitecs.query() directly
     * without requiring persistent query registration.
     *
     * Usage:
     * - for (e in Hx.query(world, [pos, vel])) { ... }
     * - for (e in Hx.query(world, [pos, vel], asBuffer)) { ... }
     * - for (e in Hx.query(world, [pos, vel], {commit: false})) { ... }
     */
    public static macro function query(world:Expr, terms:Expr, ?modifiers:Expr):Expr {
        var e = queryImpl(world, terms, modifiers);
        MacroDebug.printExpr(e, "Hx.query");
        return e;
    }

    /**
     * Type-safe component initializer macro that wraps bitecs.addComponent
     * with field validation and ergonomic initialization syntax.
     *
     * Usage: Hx.addComponent(world, eid, world.pos, {x: 10, y: 20})
     */
    public static macro function addComponent(world:Expr, eid:Expr, component:Expr, ?init:Expr):Expr {
        final e = addComponentImpl(world, eid, component, init);
        MacroDebug.printExpr(e, "Hx.addComponent");
        return e;
    }

    /**
     * Simple single-component accessor that returns a typed wrapper for direct component access.
     * Simpler alternative to HxEntity when you only need one component.
     *
     * Usage: var pos = Hx.get(eid, world.pos); pos.x = 10;
     */
    public static macro function get(eid:Expr, component:Expr):Expr {
        final e = getImpl(eid, component);
        MacroDebug.printExpr(e, "Hx.get");
        return e;
    }

    /**
     * Creates an entity wrapper for accessing multiple components from world and terms.
     *
     * Returns type `HxEntity<World, [terms]>` which can be used for type annotations.
     *
     * Usage:
     * ```haxe
     * var e = Hx.entity(world, eid, [pos, vel]);
     * e.pos.x = 10;
     * ```
     *
     * For creating from query, use `query.entity(eid)` directly.
     */
    public static macro function entity(world:Expr, eid:Expr, terms:Expr):Expr {
        final e = entityImpl(world, eid, terms);
        MacroDebug.printExpr(e, "Hx.entity");
        return e;
    }

    #if macro
    static function queryImpl(worldExpr:Expr, termsExpr:Expr, ?modifiersExpr:Expr):Expr {
        final pos = Context.currentPos();

        // Validate that terms is an array expression
        switch termsExpr.expr {
            case EArrayDecl(_):
                // Valid
            case _:
                Context.error('terms parameter must be an array literal like [pos, vel].', termsExpr.pos);
        }

        // Get world type from expression
        var worldType = Context.typeof(worldExpr);

        // Parse terms from expression, passing worldExpr for proper scoping
        var queryTermInfo = TermUtils.parseTermsFromExpr(worldType, termsExpr, true, worldExpr);

        // Generate EntityWrapperMacro type for the iterator
        var wrapperTypePath = MacroUtils.generateEntityWrapperTypePath(worldType, termsExpr);

        // Generate iterator type
        var iteratorType:TypePath = {
            pack: MacroUtils.HXBITECS_PACK,
            name: MacroUtils.QUERY_ITERATOR,
            params: [TPType(TPath(wrapperTypePath))]
        };

        // Generate component store expressions from allComponents
        // This ensures we only pass actual component stores, not operator expressions
        var componentStoreExprs = MacroUtils.generateComponentStoreExprs(worldExpr, queryTermInfo.allComponents);

        // Build arguments array for bitecs.Bitecs.query
        var queryArgs = [worldExpr, macro $a{queryTermInfo.queryExprs}];
        if (!modifiersExpr?.expr.match(EConst(CIdent("null"))))
            queryArgs.push(modifiersExpr);

        return macro {
            var queryResult = bitecs.Bitecs.query($a{queryArgs});
            new $iteratorType(queryResult, $a{componentStoreExprs});
        };
    }

    static function addComponentImpl(world:Expr, eid:Expr, component:Expr, ?init:Expr):Expr {
        var pos = Context.currentPos();

        // Validate that component is not an array expression
        switch component.expr {
            case EArrayDecl(_):
                Context.error('component parameter must be a single component store, not an array.', component.pos);
            case _:
        }

        // Normalize init - if it's null, not provided, or empty block {}, treat as no initialization
        var hasInit = switch init {
            case null | { expr: EConst(CIdent("null")) } | { expr: EBlock([]) }: false;
            case _: true;
        };

        // Type the component expression to determine its type
        var componentType = Context.typeof(component);

        // Analyze component pattern (SoA, AoS, SimpleArray, Tag)
        var pattern = MacroUtils.analyzeComponentType(componentType);

        // Generate code based on pattern
        return switch pattern {
            case Tag:
                if (hasInit) {
                    Context.error('Tag components have no fields and cannot be initialized with values', init.pos);
                }
                // Just add the component
                macro bitecs.Bitecs.addComponent($world, $eid, $component);

            case SimpleArray(_):
                // Generate wrapper type path
                var wrapperTypePath = MacroUtils.generateHxComponentTypePath(componentType);

                if (!hasInit) {
                    // Add component and return wrapper
                    macro {
                        var __comp = $component;
                        bitecs.Bitecs.addComponent($world, $eid, __comp);
                        new $wrapperTypePath({ store: __comp, eid: $eid });
                    };
                } else {
                    // Add, initialize, and return wrapper
                    macro {
                        var __comp = $component;
                        bitecs.Bitecs.addComponent($world, $eid, __comp);
                        __comp[$eid] = $init;
                        new $wrapperTypePath({ store: __comp, eid: $eid });
                    };
                }

            case AoS(_):
                generateAoSInit(world, eid, component, componentType, pattern, hasInit, init, pos);

            case SoA(_):
                generateStructuredInit(world, eid, component, componentType, pattern, hasInit, init, pos);
        }
    }

    /**
     * Common initialization logic for both SoA and AoS components.
     * Extracts, validates, and merges init fields with defaults.
     */
    static function prepareInitialization(
        componentFields:Array<MacroUtils.ComponentFieldInfo>,
        defaults:Null<Map<String, Expr>>,
        hasInit:Bool,
        init:Expr,
        pos:Position
    ):InitializationData {
        var fieldValues = new Map<String, Expr>();

        // Validate defaults (do this once upfront)
        if (defaults != null) {
            MacroUtils.validateDefaultFields(defaults, componentFields, pos);
        }

        if (!hasInit) {
            // Use defaults if available
            if (defaults != null) {
                for (field in componentFields) {
                    if (defaults.exists(field.name)) {
                        fieldValues.set(field.name, defaults.get(field.name));
                    }
                }
            }
        } else {
            // Extract and validate init fields
            var initFields = switch init.expr {
                case EObjectDecl(fields): fields;
                case _: Context.error('Initializer must be an object literal like {x: 10, y: 20}', init.pos);
            };

            MacroUtils.validateInitFields(initFields, componentFields, pos);

            // Build merged map (init overrides defaults)
            var initFieldMap = new Map<String, Expr>();
            for (initField in initFields) {
                initFieldMap.set(initField.field, initField.expr);
            }

            for (field in componentFields) {
                var fieldName = field.name;
                var fieldValue:Expr = null;

                // Init value takes precedence
                if (initFieldMap.exists(fieldName)) {
                    fieldValue = initFieldMap.get(fieldName);
                } else if (defaults != null && defaults.exists(fieldName)) {
                    fieldValue = defaults.get(fieldName);
                }

                if (fieldValue != null) {
                    fieldValues.set(fieldName, fieldValue);
                }
            }
        }

        return {
            fieldValues: fieldValues,
            hasValues: fieldValues.keys().hasNext()
        };
    }

    static function generateStructuredInit(world:Expr, eid:Expr, component:Expr, componentType:Type,
            pattern:MacroUtils.ComponentPattern, hasInit:Bool, init:Expr, pos:Position):Expr {

        var componentFields = MacroUtils.getComponentFields(componentType);
        var wrapperTypePath = MacroUtils.generateHxComponentTypePath(componentType);
        var defaults = mergeDefaults(componentType, componentFields);

        var initData = prepareInitialization(componentFields, defaults, hasInit, init, pos);

        if (!initData.hasValues) {
            // No init and no defaults - just add component and return wrapper
            return macro {
                var __comp = $component;
                bitecs.Bitecs.addComponent($world, $eid, __comp);
                new $wrapperTypePath({ store: __comp, eid: $eid });
            };
        }

        // Generate assignments from field values
        var assignments:Array<Expr> = [];
        for (componentField in componentFields) {
            var fieldName = componentField.name;
            if (initData.fieldValues.exists(fieldName)) {
                var fieldValue = initData.fieldValues.get(fieldName);
                assignments.push(macro __w.$fieldName = $fieldValue);
            }
        }

        return macro {
            var __comp = $component;
            bitecs.Bitecs.addComponent($world, $eid, __comp);
            var __w = new $wrapperTypePath({ store: __comp, eid: $eid });
            $b{assignments};
            __w;
        };
    }
    /**
     * Merge typedef-level @:defaults with field-level @:default metadata.
     * Field-level takes precedence over typedef-level.
     */
    static function mergeDefaults(componentType:Type, componentFields:Array<MacroUtils.ComponentFieldInfo>):Null<Map<String, Expr>> {
        // Start with typedef-level defaults
        var typedefDefaults = MacroUtils.getComponentDefaults(componentType);
        var merged = typedefDefaults != null ? typedefDefaults.copy() : new Map<String, Expr>();

        // Override with field-level defaults
        for (field in componentFields) {
            if (field.defaultExpr != null) {
                merged.set(field.name, field.defaultExpr);
            }
        }

        return merged.keys().hasNext() ? merged : null;
    }

    static function generateAoSInit(world:Expr, eid:Expr, component:Expr, componentType:Type,
            pattern:MacroUtils.ComponentPattern, hasInit:Bool, init:Expr, pos:Position):Expr {

        // Get element type from pattern
        var elementType = switch pattern {
            case AoS(et): et;
            case _: Context.error('generateAoSInit called with non-AoS pattern', pos);
        };

        var componentFields = MacroUtils.getComponentFields(componentType);
        var wrapperTypePath = MacroUtils.generateHxComponentTypePath(componentType);
        var defaults = mergeDefaults(elementType, componentFields);

        var initData = prepareInitialization(componentFields, defaults, hasInit, init, pos);

        if (!initData.hasValues) {
            // No initialization - add component and ensure object exists at slot
            // Creates empty object only if missing (reuses existing to avoid GC, matches SoA stale-value semantics)
            // Use cast to bypass Haxe's type check - we intentionally create empty object for JS runtime
            return macro {
                var __comp = $component;
                var __eid = $eid;
                bitecs.Bitecs.addComponent($world, __eid, __comp);
                if (__comp[__eid] == null) __comp[__eid] = cast {};
                new $wrapperTypePath({ store: __comp, eid: __eid });
            };
        }

        // Build initialization object from field values
        var objectFields:Array<ObjectField> = [];
        for (field in componentFields) {
            var fieldName = field.name;
            if (initData.fieldValues.exists(fieldName)) {
                objectFields.push({ field: fieldName, expr: initData.fieldValues.get(fieldName) });
            }
        }

        var initObject = { expr: EObjectDecl(objectFields), pos: pos };
        var elementComplexType = TypeTools.toComplexType(elementType);

        return macro {
            var __comp = $component;
            bitecs.Bitecs.addComponent($world, $eid, __comp);
            var __init:$elementComplexType = $initObject;
            __comp[$eid] = __init;
            new $wrapperTypePath({ store: __comp, eid: $eid });
        };
    }

    static function getImpl(eid:Expr, component:Expr):Expr {
        var pos = Context.currentPos();

        // Validate that component is not an array expression
        switch component.expr {
            case EArrayDecl(_):
                Context.error('component parameter must be a single component store, not an array. Use Hx.entity() for multiple components.', component.pos);
            case _:
        }

        // Type the component expression to determine its type
        var componentType = Context.typeof(component);

        // Analyze component pattern
        var pattern = MacroUtils.analyzeComponentType(componentType);

        // Generate wrapper type path
        var wrapperTypePath = MacroUtils.generateHxComponentTypePath(componentType);

        // Generate code based on pattern
        return switch pattern {
            case SoA(_) | AoS(_) | SimpleArray(_):
                macro new $wrapperTypePath({ store: $component, eid: $eid });
            case Tag:
                // Tags have no data, emit error.
                Context.error('Tag components have no data fields and cannot be accessed directly. Use their presence/absence instead.', pos);
        };
    }

    static function entityImpl(worldExpr:Expr, eidExpr:Expr, termsExpr:Expr):Expr {
        final pos = Context.currentPos();

        // Validate that terms is an array expression
        switch termsExpr.expr {
            case EArrayDecl(_):
                // Valid
            case _:
                Context.error('terms parameter must be an array literal like [pos, vel].', termsExpr.pos);
        }

        // Get world type from expression
        var worldType = Context.typeof(worldExpr);

        // Parse terms from expression, passing worldExpr for proper scoping
        var queryTermInfo = TermUtils.parseTermsFromExpr(worldType, termsExpr, true, worldExpr);

        // Generate EntityWrapperMacro type path
        var wrapperTypePath = MacroUtils.generateEntityWrapperTypePath(worldType, termsExpr);

        // Generate component store expressions from allComponents
        var componentStoreExprs = MacroUtils.generateComponentStoreExprs(worldExpr, queryTermInfo.allComponents);

        // Return new EntityWrapper(eid, [component stores])
        return macro new $wrapperTypePath($eidExpr, $a{componentStoreExprs});
    }
    #end

}

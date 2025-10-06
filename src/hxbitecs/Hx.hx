package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import hxbitecs.MacroDebug;
#end

/**
 * Main HxBitECS utility class providing macro-powered wrapper functions.
 */
class Hx {

    /**
     * Expression macro for ad-hoc queries that use bitecs.Bitecs.query() directly
     * without requiring persistent query registration.
     *
     * Usage: for (e in Hx.query(world, [pos, vel])) { ... }
     */
    public static macro function query(world:Expr, terms:Expr):Expr {
        var e = queryImpl(world, terms);
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
    static function queryImpl(worldExpr:Expr, termsExpr:Expr):Expr {
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

        // Parse terms from expression
        var queryTermInfo = TermUtils.parseTermsFromExpr(worldType, termsExpr);

        // Generate EntityWrapperMacro type for the iterator
        var wrapperComplexType = TPath({
            pack: ['hxbitecs'],
            name: 'EntityWrapperMacro',
            params: [
                TPType(TypeTools.toComplexType(worldType)),
                TPExpr(termsExpr)
            ]
        });

        // Generate iterator type
        var iteratorType:TypePath = {
            pack: ['hxbitecs'],
            name: 'QueryIterator',
            params: [TPType(wrapperComplexType)]
        };

        // Generate component store expressions from allComponents
        // This ensures we only pass actual component stores, not operator expressions
        var componentStoreExprs:Array<Expr> = [];
        for (termInfo in queryTermInfo.allComponents) {
            var componentName = termInfo.name;
            componentStoreExprs.push(macro $worldExpr.$componentName);
        }

        // Generate block expression that creates the iterator directly
        return macro {
            var queryResult = bitecs.Bitecs.query($worldExpr, $a{queryTermInfo.queryExprs});
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
                var wrapperTypePath:TypePath = {
                    pack: ['hxbitecs'],
                    name: 'HxComponent',
                    params: [TPType(TypeTools.toComplexType(componentType))]
                };

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

    static function generateStructuredInit(world:Expr, eid:Expr, component:Expr, componentType:Type,
            pattern:MacroUtils.ComponentPattern, hasInit:Bool, init:Expr, pos:Position):Expr {

        // Get component fields
        var componentFields = MacroUtils.getComponentFields(componentType);

        // Generate wrapper type path
        var wrapperTypePath:TypePath = {
            pack: ['hxbitecs'],
            name: 'HxComponent',
            params: [TPType(TypeTools.toComplexType(componentType))]
        };

        // Merge typedef-level and field-level defaults (field-level wins)
        var defaults = mergeDefaults(componentType, componentFields);

        if (!hasInit) {
            // If no init provided but we have defaults, use them
            if (defaults != null && defaults.keys().hasNext()) {
                // Validate defaults: check for extra fields not in component
                var componentFieldNames = [for (f in componentFields) f.name];
                for (fieldName in defaults.keys()) {
                    if (!componentFieldNames.contains(fieldName)) {
                        Context.warning('Default field "$fieldName" does not exist in component. Available fields: ${componentFieldNames.join(", ")}', pos);
                    }
                }

                // Generate assignments from defaults
                var assignments:Array<Expr> = [];
                for (fieldName in defaults.keys()) {
                    if (componentFieldNames.contains(fieldName)) {
                        var defaultValue = defaults.get(fieldName);
                        assignments.push(macro __w.$fieldName = $defaultValue);
                    }
                }

                return macro {
                    var __comp = $component;
                    bitecs.Bitecs.addComponent($world, $eid, __comp);
                    var __w = new $wrapperTypePath({ store: __comp, eid: $eid });
                    $b{assignments};
                    __w;
                };
            } else {
                // No init and no defaults - just add component and return wrapper
                return macro {
                    var __comp = $component;
                    bitecs.Bitecs.addComponent($world, $eid, __comp);
                    new $wrapperTypePath({ store: __comp, eid: $eid });
                };
            }
        }

        // Extract initializer fields from the object literal
        var initFields = switch init.expr {
            case EObjectDecl(fields):
                fields;
            case _:
                Context.error('Initializer must be an object literal like {x: 10, y: 20}', init.pos);
        };

        // Validate fields: check for extra fields not in component
        var componentFieldNames = [for (f in componentFields) f.name];
        for (initField in initFields) {
            if (!componentFieldNames.contains(initField.field)) {
                Context.error('Field "${initField.field}" does not exist in component. Available fields: ${componentFieldNames.join(", ")}',
                    initField.expr.pos);
            }
        }

        // Validate defaults: check for extra fields not in component
        if (defaults != null) {
            for (fieldName in defaults.keys()) {
                if (!componentFieldNames.contains(fieldName)) {
                    Context.warning('Default field "$fieldName" does not exist in component. Available fields: ${componentFieldNames.join(", ")}', pos);
                }
            }
        }

        // Build combined field assignments: init values override defaults
        var assignments:Array<Expr> = [];
        var initFieldMap = new Map<String, Expr>();
        for (initField in initFields) {
            initFieldMap.set(initField.field, initField.expr);
        }

        // Assign fields in order of component definition
        for (componentField in componentFields) {
            var fieldName = componentField.name;
            var fieldValue:Expr = null;

            // Check if provided in init
            if (initFieldMap.exists(fieldName)) {
                fieldValue = initFieldMap.get(fieldName);
            }
            // Otherwise check if has default
            else if (defaults != null && defaults.exists(fieldName)) {
                fieldValue = defaults.get(fieldName);
            }

            // Generate assignment if we have a value
            if (fieldValue != null) {
                assignments.push(macro __w.$fieldName = $fieldValue);
            }
        }

        // Generate the full initialization block
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

        // Get component fields (from element type of array)
        var componentFields = MacroUtils.getComponentFields(componentType);

        // Generate wrapper type path
        var wrapperTypePath:TypePath = {
            pack: ['hxbitecs'],
            name: 'HxComponent',
            params: [TPType(TypeTools.toComplexType(componentType))]
        };

        // Merge typedef-level and field-level defaults (field-level wins)
        var defaults = mergeDefaults(elementType, componentFields);

        // Generate element type complex type for typing the init object
        var elementComplexType = TypeTools.toComplexType(elementType);

        // Build the initialization object
        var initObject:Expr = null;

        if (!hasInit) {
            // No init provided - use all defaults if available
            if (defaults != null && defaults.keys().hasNext()) {
                var objectFields:Array<ObjectField> = [];
                for (field in componentFields) {
                    if (defaults.exists(field.name)) {
                        objectFields.push({ field: field.name, expr: defaults.get(field.name) });
                    }
                }

                if (objectFields.length > 0) {
                    initObject = { expr: EObjectDecl(objectFields), pos: pos };
                }
            }
        } else {
            // Init provided - merge with defaults
            var initFields = switch init.expr {
                case EObjectDecl(fields):
                    fields;
                case _:
                    Context.error('Initializer must be an object literal like {hp: 100, maxHp: 150}', init.pos);
            };

            // Validate init fields
            var componentFieldNames = [for (f in componentFields) f.name];
            for (initField in initFields) {
                if (!componentFieldNames.contains(initField.field)) {
                    Context.error('Field "${initField.field}" does not exist in component. Available fields: ${componentFieldNames.join(", ")}',
                        init.pos);
                }
            }

            // Validate defaults
            if (defaults != null) {
                for (fieldName in defaults.keys()) {
                    if (!componentFieldNames.contains(fieldName)) {
                        Context.warning('Default field "$fieldName" does not exist in component. Available fields: ${componentFieldNames.join(", ")}', pos);
                    }
                }
            }

            // Build merged object: init values override defaults
            var initFieldMap = new Map<String, Expr>();
            for (initField in initFields) {
                initFieldMap.set(initField.field, initField.expr);
            }

            var objectFields:Array<ObjectField> = [];
            for (field in componentFields) {
                var fieldName = field.name;
                var fieldValue:Expr = null;

                // Check if provided in init
                if (initFieldMap.exists(fieldName)) {
                    fieldValue = initFieldMap.get(fieldName);
                }
                // Otherwise check if has default
                else if (defaults != null && defaults.exists(fieldName)) {
                    fieldValue = defaults.get(fieldName);
                }

                // Add to object if we have a value
                if (fieldValue != null) {
                    objectFields.push({ field: fieldName, expr: fieldValue });
                }
            }

            if (objectFields.length > 0) {
                initObject = { expr: EObjectDecl(objectFields), pos: pos };
            }
        }

        // Generate code
        if (initObject != null) {
            return macro {
                var __comp = $component;
                bitecs.Bitecs.addComponent($world, $eid, __comp);
                var __init:$elementComplexType = $initObject;
                __comp[$eid] = __init;
                new $wrapperTypePath({ store: __comp, eid: $eid });
            };
        } else {
            // No initialization - just add component and return wrapper
            return macro {
                var __comp = $component;
                bitecs.Bitecs.addComponent($world, $eid, __comp);
                new $wrapperTypePath({ store: __comp, eid: $eid });
            };
        }
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
        var wrapperTypePath:TypePath = {
            pack: ['hxbitecs'],
            name: 'HxComponent',
            params: [TPType(TypeTools.toComplexType(componentType))]
        };

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

        // Parse terms from expression
        var queryTermInfo = TermUtils.parseTermsFromExpr(worldType, termsExpr);

        // Generate EntityWrapperMacro type path
        var wrapperTypePath:TypePath = {
            pack: ['hxbitecs'],
            name: 'EntityWrapperMacro',
            params: [
                TPType(TypeTools.toComplexType(worldType)),
                TPExpr(termsExpr)
            ]
        };

        // Generate component store expressions from allComponents
        var componentStoreExprs:Array<Expr> = [];
        for (termInfo in queryTermInfo.allComponents) {
            var componentName = termInfo.name;
            componentStoreExprs.push(macro $worldExpr.$componentName);
        }

        // Return new EntityWrapper(eid, [component stores])
        return macro new $wrapperTypePath($eidExpr, $a{componentStoreExprs});
    }
    #end

}

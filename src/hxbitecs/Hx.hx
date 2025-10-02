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
     * Usage: Hx.addComponent(world, eid, pos, {x: 10, y: 20})
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

    #if macro
    static function queryImpl(worldExpr:Expr, termsExpr:Expr):Expr {
        final pos = Context.currentPos();

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

        // Normalize init - if it's null or not provided, treat as no initialization
        var hasInit = switch init {
            case null | { expr: EConst(CIdent("null")) }: false;
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

            case SimpleArray(_) | AoS(_):
                if (!hasInit) {
                    // Just add the component without initialization
                    macro bitecs.Bitecs.addComponent($world, $eid, $component);
                } else {
                    // Add and initialize with direct assignment
                    macro {
                        var __comp = $component;
                        bitecs.Bitecs.addComponent($world, $eid, __comp);
                        __comp[$eid] = $init;
                    };
                }

            case SoA(_):
                generateStructuredInit(world, eid, component, componentType, pattern, hasInit, init, pos);
        }
    }

    static function generateStructuredInit(world:Expr, eid:Expr, component:Expr, componentType:Type,
            pattern:MacroUtils.ComponentPattern, hasInit:Bool, init:Expr, pos:Position):Expr {

        // Get component fields
        var componentFields = MacroUtils.getComponentFields(componentType);

        if (!hasInit) {
            // Just add component without initialization
            return macro bitecs.Bitecs.addComponent($world, $eid, $component);
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

        // Generate wrapper type path
        var wrapperTypePath:TypePath = {
            pack: ['hxbitecs'],
            name: 'HxComponent',
            params: [TPType(TypeTools.toComplexType(componentType))]
        };

        // Generate field assignments
        var assignments:Array<Expr> = [];
        for (initField in initFields) {
            var fieldName = initField.field;
            var fieldValue = initField.expr;
            assignments.push(macro __w.$fieldName = $fieldValue);
        }

        // Generate the full initialization block
        return macro {
            var __comp = $component;
            bitecs.Bitecs.addComponent($world, $eid, __comp);
            var __w = new $wrapperTypePath({ store: __comp, eid: $eid });
            $b{assignments};
        };
    }
    static function getImpl(eid:Expr, component:Expr):Expr {
        var pos = Context.currentPos();

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
    #end

}

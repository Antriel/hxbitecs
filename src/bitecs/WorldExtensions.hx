package bitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import bitecs.World.ComponentData;

using tink.MacroApi;
#end

class WorldExtensions {

    #if !macro
    public static inline function addEntity(world:AnyWorld) {
        return Bitecs.addEntity(world);
    }

    public static inline function removeEntity(world:AnyWorld, eid:Entity) {
        return Bitecs.removeEntity(world, eid);
    }

    public static inline function getEntityComponents(world:AnyWorld, eid:Entity):Array<Dynamic> {
        return Bitecs.getEntityComponents(world, eid);
    }

    public static inline function entityExists(world:AnyWorld, eid:Entity) {
        return Bitecs.entityExists(world, eid);
    }

    public static inline function removeAllComponents(world:AnyWorld, eid:Entity, reset:Bool = false) {
        final comps = Bitecs.getEntityComponents(world, eid);
        for (c in comps) Bitecs.removeComponent(world, c, eid, reset);
    }
    #end

    public static macro function addComponent(world:ExprOf<AnyWorld>, comp:Expr, eid:ExprOf<Entity>, init = null) {
        var initFields = switch init.expr {
            case EConst(CIdent('null')): [];
            case EObjectDecl(fields): fields;
            case _: Context.error('Expected object declaration.', init.pos);
        }
        var result = processCompExpr(comp, (comp, pos) -> {
            var cname = comp.name;
            var wrapper = comp.def.wrapperPath;
            var args = [];
            for (arg in comp.def.initExtraArgs) {
                var i = Lambda.findIndex(initFields, f -> f.field == arg.name);
                var expr = if (i < 0) {
                    if (arg.value != null) arg.value;
                    else Context.error('Missing initialization value for "${arg.name}".', pos);
                } else initFields.splice(i, 1)[0].expr;
                args.push(expr);
            }
            macro @:pos(pos) @:mergeBlock {
                bitecs.Bitecs.addComponent($world, $world.$cname, $eid);
                var $cname = new $wrapper($eid, $world.$cname);
                $i{cname}.init($a{args});
            };
        });
        for (field in initFields) {
            Context.warning('Unused field.', field.expr.pos);
        }
        return result;
    }

    public static macro function hasComponent(world:ExprOf<AnyWorld>, comp:Expr, eid:ExprOf<Entity>) {
        return processCompExpr(comp, (comp, pos) -> {
            var cname = comp.name;
            macro @:pos(pos) var $cname = bitecs.Bitecs.hasComponent($world, $world.$cname, $eid);
        });
    }

    public static macro function hasAllComponents(world:ExprOf<AnyWorld>, comp:Expr, eid:ExprOf<Entity>) {
        return processCompExpr(comp, (comp, pos) -> {
            var cname = comp.name;
            macro @:pos(pos) bitecs.Bitecs.hasComponent($world, $world.$cname, $eid);
        }, MergeAnd);
    }

    public static macro function getComponent(world:ExprOf<AnyWorld>, comp:Expr, eid:ExprOf<Entity>) {
        return processCompExpr(comp, (comp, pos) -> {
            var cname = comp.name;
            var wrapper = comp.def.wrapperPath;
            macro @:pos(pos) var $cname = new $wrapper($eid, $world.$cname);
        });
    }

    public static macro function removeComponent(world:ExprOf<AnyWorld>, comp:Expr, eid:ExprOf<Entity>, ?reset:ExprOf<Bool>) {
        return processCompExpr(comp, (comp, pos) -> {
            var cname = comp.name;
            var args = [world, macro @:pos(pos) $world.$cname, eid];
            if (!reset.expr.match(EConst(CIdent('null')))) args.push(reset);
            macro @:pos(pos) bitecs.Bitecs.removeComponent($a{args});
        }, NoReturn);
    }

    #if macro
    private static function processCompExpr(comp:Expr, action:(comp:ComponentData, pos:Position) -> Expr, mode = ExprMode.Normal):Expr {
        var res = [];
        var names = [];
        function add(cExpr:Expr) {
            var compData = null;
            try {
                final type = Context.getType(cExpr.toString());
                compData = World.components.get(type);
                if (compData == null) Context.error('Component not registered, is it used in any query?', cExpr.pos);
            } catch (e) {
                Context.error('Could not find type: $e', cExpr.pos);
            }
            names.push(compData.name);
            res.push(action(compData, cExpr.pos));
        }
        switch comp.expr {
            case EArrayDecl(values):
                for (v in values) add(v);
                // Result value is anon object of all wrappers.
                switch mode {
                    case Normal:
                        res.push(EObjectDecl(names.map(n -> ({ field: n, expr: macro $i{n} }:ObjectField))).at());
                    case MergeAnd:
                        res = [Lambda.fold(res.slice(1), (expr, res:Expr) -> res.binOp(expr, OpBoolAnd), res[0])];
                    case NoReturn:
                }
            case _:
                add(comp);
                switch mode {
                    case Normal: // Result value is just the single wrapper.
                        res.push(macro $i{names[0]});
                    case MergeAnd:
                    case NoReturn:
                }
        }
        return res.toBlock();
    }
    #end

}

#if !macro
typedef AnyWorld = World.IWorld<Dynamic>
#end

#if macro
enum ExprMode {

    Normal;
    NoReturn;
    MergeAnd;

}
#end

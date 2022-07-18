package bitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using tink.MacroApi;
#end

class WorldExtensions {

    #if !macro
    public static inline function addEntity(world:World.IWorld) {
        return Bitecs.addEntity(world);
    }

    public static inline function removeEntity(world:World.IWorld, eid:Entity) {
        return Bitecs.removeEntity(world, eid);
    }

    public static inline function getEntityComponents(world:World.IWorld, eid:Entity):Array<Dynamic> {
        return Bitecs.getEntityComponents(world, eid);
    }

    public static inline function entityExists(world:World.IWorld, eid:Entity) {
        return Bitecs.entityExists(world, eid);
    }
    #end

    public static macro function addComponent(world:ExprOf<World.IWorld>, comp:Expr, eid:ExprOf<Entity>) {
        return processCompExpr(comp, (cname, wrapper) -> macro @:mergeBlock {
            bitecs.Bitecs.addComponent($world, $world.$cname, $eid);
            var $cname = new $wrapper($eid, $world.$cname);
            $i{cname}.init();
        });
    }

    public static macro function hasComponent(world:ExprOf<World.IWorld>, comp:Expr, eid:ExprOf<Entity>) {
        return processCompExpr(comp,
            (cname, wrapper) -> macro var $cname = bitecs.Bitecs.hasComponent($world, $world.$cname, $eid)
        );
    }

    public static macro function getComponent(world:ExprOf<World.IWorld>, comp:Expr, eid:ExprOf<Entity>) {
        return processCompExpr(comp, (cname, wrapper) -> macro var $cname = new $wrapper($eid, $world.$cname));
    }

    public static macro function removeComponent(world:ExprOf<World.IWorld>, comp:Expr, eid:ExprOf<Entity>, ?reset:ExprOf<Bool>) {
        return processCompExpr(comp, (cname, wrapper) -> {
            var args = [world, macro $world.$cname, eid];
            if (!reset.expr.match(EConst(CIdent('null')))) args.push(reset);
            macro bitecs.Bitecs.removeComponent($a{args});
        }, false);
    }

    #if macro
    private static function processCompExpr(comp:Expr, action:(name:String, wrapper:TypePath) -> Expr, ret = true):Expr {
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
            res.push(action(compData.name, compData.def.wrapperPath));
        }
        switch comp.expr {
            case EArrayDecl(values):
                for (v in values) add(v);
                // Result value is anon object of all wrappers.
                if (ret) res.push(EObjectDecl(names.map(n -> ({ field: n, expr: macro $i{n} }:ObjectField))).at());
            case _:
                add(comp);
                // Result value is just the single wrapper;
                if (ret) res.push(macro $i{names[0]});
        }
        return res.toBlock();
    }
    #end

}

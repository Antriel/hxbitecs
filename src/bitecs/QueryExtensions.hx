package bitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using tink.MacroApi;
#end

class QueryExtensions {

    public static macro function sort(iter:ExprOf<QueryIter>, expr:Expr) {
        var func = macro function(aE, bE) {
            var a = iter.getWrapper(aE);
            var b = iter.getWrapper(bE);
            return $expr;
        }
        var e = iter.field('ents').field('sort').call([func]);
        var t = Context.typeof(iter).toComplex();
        return macro {
            var iter = $iter;
            iter.ents.sort($func);
            (iter:$t);
        };
    }

}

typedef QueryIter = {

    final ents:Array<Entity>;
    function getWrapper(eid:Entity):Dynamic;

}

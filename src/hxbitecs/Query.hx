package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

/**
 * Expression macro for creating ad-hoc queries that use bitecs.Bitecs.query() directly
 * without requiring persistent query registration.
 *
 * Usage: for (e in query(world, [pos, vel])) { ... }
 */
class Query {

    // #if !macro
    /**
     * Expression macro for ad-hoc queries.
     * @param world The world instance
     * @param terms The query terms array
     * @return Iterator over entities matching the query
     */
    public static macro function query(world:Expr, terms:Expr):Expr {
        var e = queryImpl(world, terms);
        trace(new haxe.macro.Printer().printExpr(e));
        return e;
    }
    // #end

    #if macro
    static function queryImpl(worldExpr:Expr, termsExpr:Expr):Expr {
        final pos = Context.currentPos();

        // Get world type from expression
        var worldType = Context.typeof(worldExpr);

        // Generate type path for AdHocQuery
        var adHocQueryTypePath = {
            pack: ['hxbitecs'],
            name: 'AdHocQuery',
            params: [
                TPType(TypeTools.toComplexType(worldType)),
                TPExpr(termsExpr)
            ]
        };

        // Return simple rewrite to new AdHocQuery<World, [terms]>(world)
        return {
            expr: ENew(adHocQueryTypePath, [worldExpr]),
            pos: pos
        };
    }
    #end
}

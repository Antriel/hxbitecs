package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import hxbitecs.MacroDebug;
#end

#if !macro
@:genericBuild(hxbitecs.HxQuery.build()) class HxQuery<Data, Rest> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [target, terms]):
            var baseName = MacroUtils.getBaseName(target);
            var queryTermInfo = TermUtils.parseTerms(target, terms);
            var name = 'Query${baseName}_${queryTermInfo.structureId}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () ->
                generateQuery(name, target, terms, queryTermInfo));
        case _:
            Context.error("HxQuery requires exactly one type parameter", Context.currentPos());
    }
}

function generateQuery(name:String, target:Type, terms:Type,
        queryTermInfo:TermUtils.QueryTermInfo):Array<TypeDefinition> {
    final pos = Context.currentPos();

    var queryFields:Array<Field> = [];
    var constructorArgs = [{ name: "world", type: TypeTools.toComplexType(target) }];
    // Use the parsed query expressions instead of simple component references
    var queryTermsExpr = queryTermInfo.queryExprs;

    var constructor:Field = {
        name: "new",
        kind: FFun({
            args: constructorArgs,
            expr: macro {
                this = bitecs.Bitecs.registerQuery(world, $a{queryTermsExpr});
            }
        }),
        pos: pos,
        access: [APublic, AInline]
    };
    queryFields.push(constructor);

    var termsExpr = switch terms {
        case TInst(_.get().kind => KExpr(expr), _): expr;
        case _: Context.error('Unsupported terms type: $terms', pos);
    };
    var wrapperTypePath = MacroUtils.generateEntityWrapperTypePath(target, termsExpr);

    final iterTp:TypePath = {
        pack: MacroUtils.HXBITECS_PACK,
        name: MacroUtils.QUERY_ITERATOR,
        params: [TPType(TPath(wrapperTypePath))]
    };

    // Generate array literal with explicit indices for component stores
    // e.g., [this.allComponents[0], this.allComponents[1], ...]
    var componentArrayExprs = MacroUtils.generateComponentArrayExprs(queryTermInfo.allComponents.length);

    var iteratorMethod:Field = {
        name: "iterator",
        kind: FFun({
            args: [],
            ret: TPath(iterTp),
            expr: macro return new $iterTp(this.dense.asType1, $a{componentArrayExprs})
        }),
        pos: pos,
        access: [APublic, AInline]
    };
    queryFields.push(iteratorMethod);

    // Generate entity() method that returns an entity wrapper for a specific eid
    // Returns type HxEntity<World, [terms]> matching this query's component terms

    var entityMethod:Field = {
        name: "entity",
        kind: FFun({
            args: [{ name: "eid", type: macro :Int }],
            ret: TPath(wrapperTypePath),
            expr: macro return new $wrapperTypePath(eid, $a{componentArrayExprs})
        }),
        pos: pos,
        access: [APublic, AInline],
        doc: "Creates an entity wrapper for a specific entity ID.\n\nReturns type `HxEntity<World, [terms]>` matching this query's component terms.\n\nUsage: `var e = query.entity(eid); e.pos.x = 10;`"
    };
    queryFields.push(entityMethod);

    var queryDef:TypeDefinition = {
        name: name,
        pack: MacroUtils.HXBITECS_PACK,
        pos: pos,
        kind: TDAbstract(TPath({ pack: ['bitecs', 'core', 'query'], name: 'Query' })),
        fields: queryFields
    };
    MacroDebug.printTypeDefinition(queryDef, name);
    return [queryDef];
}
#end

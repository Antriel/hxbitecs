package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.QueryMacro.build()) class QueryMacro<Data, Rest> { }

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
            Context.error("QueryMacro requires exactly one type parameter", Context.currentPos());
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

    final iterTp:TypePath = {
        pack: ['hxbitecs'],
        name: 'QueryIterator',
        params: [
            TPType(TPath({
                pack: ['hxbitecs'],
                name: 'EntityWrapperMacro',
                params: [
                    TPType(TypeTools.toComplexType(target)),
                    TPExpr(switch terms {
                        case TInst(_.get().kind => KExpr(expr), _): expr;
                        case _: Context.error('Unsupported terms type: $terms', pos);
                    }),
                ]
            }))
        ]
    };

    // Generate array literal with explicit indices for component stores
    // e.g., [this.allComponents[0], this.allComponents[1], ...]
    var componentArrayExprs:Array<Expr> = [];
    for (i in 0...queryTermInfo.allComponents.length) {
        var index = macro $v{i};
        componentArrayExprs.push(macro this.allComponents[$index]);
    }

    var iteratorMethod:Field = {
        name: "iterator",
        kind: FFun({
            args: [],
            expr: macro return new $iterTp(this.dense.asType1, $a{componentArrayExprs})
        }),
        pos: pos,
        access: [APublic, AInline]
    };
    queryFields.push(iteratorMethod);

    var queryDef:TypeDefinition = {
        name: name,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDAbstract(TPath({ pack: ['bitecs', 'core', 'query'], name: 'Query' })),
        fields: queryFields
    };
    trace(new haxe.macro.Printer().printTypeDefinition(queryDef));
    return [queryDef];
}
#end

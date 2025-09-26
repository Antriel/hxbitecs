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
            var termInfos = TermUtils.parseTerms(target, terms);
            var termFields = [for (term in termInfos) term.name];
            var name = 'Query${baseName}_${termFields.join('_')}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () -> generateQuery(name, target, terms, termInfos));
        case _:
            Context.error("QueryMacro requires exactly one type parameter", Context.currentPos());
    }
}

function generateQuery(name:String, target:Type, terms:Type,
        termInfos:Array<TermUtils.TermInfo>):Array<TypeDefinition> {
    final pos = Context.currentPos();

    var queryFields:Array<Field> = [];
    var constructorArgs = [{ name: "world", type: TypeTools.toComplexType(target) }];
    var worldComponentsExpr = [for (termInfo in termInfos) {
        final name = termInfo.name;
        macro world.$name;
    }];

    var constructor:Field = {
        name: "new",
        kind: FFun({
            args: constructorArgs,
            expr: macro {
                this = bitecs.Bitecs.registerQuery(world, $a{worldComponentsExpr});
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
                name: 'CompWrapperMacro',
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

    var iteratorMethod:Field = {
        name: "iterator",
        kind: FFun({
            args: [],
            expr: macro return new $iterTp(this)
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

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
            var termFields = getTermFields(terms);
            var name = 'Query${baseName}_${termFields.join('_')}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () -> generateQuery(name, target, termFields));
        case _:
            Context.error("QueryMacro requires exactly one type parameter", Context.currentPos());
    }
}

function getTermFields(terms:Type):Array<String> {
    return switch terms {
        case TInst(_.get().kind => KExpr({ expr: EArrayDecl(values) }), _):
            var fields = [];
            for (v in values) switch v.expr {
                case EConst(CIdent(s)): fields.push(s);
                case _: Context.error('Unsupported term type: $v', v.pos);
            }
            fields;
        case _:
            Context.error('Expected TInst(KExpr(EArrayDecl())) for terms, got: $terms', Context.currentPos());
    }
}

function generateQuery(name:String, target:Type, termFields:Array<String>):Array<TypeDefinition> {
    final pos = Context.currentPos();

    var wrapperName = name + 'Wrapper';
    var queryFields:Array<Field> = [];
    var constructorArgs = [{ name: "world", type: TypeTools.toComplexType(target) }];
    var worldComponentsExpr = [for (field in termFields) macro world.$field];

    var constructor:Field = {
        name: "new",
        kind: FFun({
            args: constructorArgs,
            expr: macro {
                this = bitecs.Bitecs.registerQuery(world, $a{worldComponentsExpr});
            }
        }),
        pos: pos,
        access: [APublic]
    };
    queryFields.push(constructor);

    final iterTp:TypePath = {
        pack: ['hxbitecs'],
        name: 'QueryIterator',
        params: [
            TPType(TPath({ pack: ['hxbitecs'], name: wrapperName }))
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

    // Generate the wrapper class.
    var wrapperFields:Array<Field> = [];

    // Basic fields
    wrapperFields.push({
        name: "query",
        kind: FVar(TPath({ pack: ['bitecs', 'core', 'query'], name: 'Query' })),
        pos: pos,
        access: [APublic, AFinal]
    });

    wrapperFields.push({
        name: "eid",
        kind: FVar(TPath({ pack: [], name: 'Int' })),
        pos: pos,
        access: [APublic, AFinal]
    });

    // Component field accessors - mock for now
    var componentIndex = 0;
    for (field in termFields) {
        wrapperFields.push({
            name: field,
            kind: FVar(TPath({ pack: [], name: 'Dynamic' })), // Mock - will be proper wrapper later
            pos: pos,
            access: [APublic, AFinal]
        });
        componentIndex++;
    }

    // Constructor
    var wrapperConstructorExprs = [
        macro this.eid = eid,
        macro this.query = query
    ];

    componentIndex = 0;
    for (field in termFields) {
        var index = macro $v{componentIndex};
        wrapperConstructorExprs.push(macro this.$field = query.allComponents[$index]); // Mock assignment
        componentIndex++;
    }

    wrapperFields.push({
        name: "new",
        kind: FFun({
            args: [
                { name: "eid", type: TPath({ pack: [], name: 'Int' }) },
                { name: "query", type: TPath({ pack: ['bitecs', 'core', 'query'], name: 'Query' }) }
            ],
            ret: null,
            expr: { expr: EBlock(wrapperConstructorExprs), pos: pos }
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    var wrapperDef:TypeDefinition = {
        name: wrapperName,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDClass(),
        fields: wrapperFields
    };

    // trace(new haxe.macro.Printer().printTypeDefinition(queryDef));
    // trace(new haxe.macro.Printer().printTypeDefinition(wrapperDef));

    return [queryDef, wrapperDef];
}
#end

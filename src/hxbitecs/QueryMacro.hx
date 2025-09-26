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
            // TODO add `terms` to the name too.
            var name = 'Query' + baseName;
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () -> generateQuery(target));
        case _:
            Context.error("QueryMacro requires exactly one type parameter", Context.currentPos());
    }
}

function generateQuery(target:Type):TypeDefinition {
    final pos = Context.currentPos();

    var baseName = MacroUtils.getBaseName(target);
    var queryName = 'Query' + baseName;
    var wrapperName = queryName + 'Wrapper';

    var targetFields = MacroUtils.getTypeFields(target);

    var queryFields:Array<Field> = [];

    var constructorArgs = [{ name: "world", type: TypeTools.toComplexType(target) }];
    var worldComponentsExpr = [for (field in targetFields) macro world.$field];

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
        name: queryName,
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
    for (field in targetFields) {
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
    for (field in targetFields) {
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

    // Register all generated types
    Context.defineType(wrapperDef);

    // trace(new haxe.macro.Printer().printTypeDefinition(queryDef));
    // trace(new haxe.macro.Printer().printTypeDefinition(wrapperDef));

    return queryDef;
}
#end

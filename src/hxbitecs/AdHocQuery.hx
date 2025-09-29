package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.AdHocQuery.build()) class AdHocQuery<World, Rest> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [world, terms]):
            var baseName = MacroUtils.getBaseName(world);
            var queryTermInfo = TermUtils.parseTerms(world, terms);
            var name = 'AdHocQuery${baseName}_${queryTermInfo.structureId}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () ->
                generateAdHocQuery(name, world, terms, queryTermInfo));
        case _:
            Context.error("AdHocQuery requires exactly two type parameters", Context.currentPos());
    }
}

function generateAdHocQuery(name:String, world:Type, terms:Type,
        queryTermInfo:TermUtils.QueryTermInfo):Array<TypeDefinition> {
    final pos = Context.currentPos();

    var queryFields:Array<Field> = [];
    var constructorArgs = [{ name: "world", type: TypeTools.toComplexType(world) }];

    // Constructor that calls bitecs.Bitecs.query() directly
    var constructor:Field = {
        name: "new",
        kind: FFun({
            args: constructorArgs,
            expr: macro {
                final queryResult = bitecs.Bitecs.query(world, $a{queryTermInfo.queryExprs});
                this = new hxbitecs.AdHocQueryIterator(queryResult, $a{queryTermInfo.queryExprs});
            }
        }),
        pos: pos,
        access: [APublic, AInline]
    };
    queryFields.push(constructor);

    // Generate entity wrapper type for iterator
    var wrapperName = 'AdHocEntityWrapper${MacroUtils.getBaseName(world)}_${queryTermInfo.structureId}';
    var wrapperTypePath = { pack: ['hxbitecs'], name: wrapperName };
    var wrapperComplexType = TPath(wrapperTypePath);

    // Generate wrapper class if it doesn't exist
    if (!MacroUtils.isGenerated(wrapperName)) {
        var wrapperDefs = EntityMacroUtils.generateEntityClass(wrapperName, world, queryTermInfo.allComponents, Wrapper);
        Context.defineModule('hxbitecs.$wrapperName', wrapperDefs);
        MacroUtils.setGenerated(wrapperName);
    }

    // Iterator type for the query result
    final iterTp:ComplexType = TPath({
        pack: ['hxbitecs'],
        name: 'AdHocQueryIterator',
        params: [TPType(wrapperComplexType)]
    });

    var iteratorMethod:Field = {
        name: "iterator",
        kind: FFun({
            args: [],
            expr: macro return this
        }),
        pos: pos,
        access: [APublic, AInline]
    };
    queryFields.push(iteratorMethod);

    var queryDef:TypeDefinition = {
        name: name,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDAbstract(iterTp),
        fields: queryFields
    };

    trace(new haxe.macro.Printer().printTypeDefinition(queryDef));
    return [queryDef];
}
#end

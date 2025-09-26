package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.EntityWrapperMacro.build()) class EntityWrapperMacro<World, Rest> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [world, terms]):
            var baseName = MacroUtils.getBaseName(world);
            var queryTermInfo = TermUtils.parseTerms(world, terms);
            var name = 'EntityWrapper${baseName}_${queryTermInfo.structureId}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () ->
                generateWrapper(name, world, queryTermInfo.allComponents));
        case _:
            Context.error("EntityWrapperMacro requires exactly two type parameters", Context.currentPos());
    }
}

function generateWrapper(name:String, world:Type, termInfos:Array<TermUtils.TermInfo>):Array<TypeDefinition> {
    final pos = Context.currentPos();

    // Determine wrapper types for each component without generating them
    var componentWrappers:Array<{name:String, wrapperType:ComplexType, pattern:MacroUtils.ComponentPattern}> = [];

    for (termInfo in termInfos) {
        var pattern = MacroUtils.analyzeComponentType(termInfo.componentType);
        var wrapperType:ComplexType;

        switch pattern {
            case SoA(_) | AoS(_) | Tag:
                wrapperType = TPath({
                    pack: ['hxbitecs'],
                    name: 'ComponentWrapperMacro',
                    params: [TPType(TypeTools.toComplexType(termInfo.componentType))]
                });
        }
        componentWrappers.push({
            name: termInfo.name,
            wrapperType: wrapperType,
            pattern: pattern
        });
    }

    // Generate the main wrapper class
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

    // Component field accessors - using generic wrapper types
    for (wrapper in componentWrappers) {
        wrapperFields.push({
            name: wrapper.name,
            kind: FVar(wrapper.wrapperType),
            pos: pos,
            access: [APublic, AFinal]
        });
    }

    // Constructor
    var wrapperConstructorExprs = [
        macro this.eid = eid,
        macro this.query = query
    ];

    var componentIndex = 0;
    for (wrapper in componentWrappers) {
        var index = macro $v{componentIndex};
        final wrapperName = wrapper.name;
        var wrapperTypePath = switch wrapper.wrapperType {
            case TPath(p): p;
            case _: Context.error('Unexpected wrapper type for $wrapperName', pos);
        };

        switch wrapper.pattern {
            case SoA(_) | AoS(_):
                // For SoA and AoS, create wrapper with store and eid
                wrapperConstructorExprs.push(macro this.$wrapperName = new $wrapperTypePath({
                    store: query.allComponents[$index],
                    eid: eid
                }));
            case Tag:
                // For tag components, just pass the eid
                wrapperConstructorExprs.push(macro this.$wrapperName = new $wrapperTypePath(eid));
        }
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
        name: name,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDClass(),
        fields: wrapperFields
    };

    trace(new haxe.macro.Printer().printTypeDefinition(wrapperDef));
    return [wrapperDef];
}
#end

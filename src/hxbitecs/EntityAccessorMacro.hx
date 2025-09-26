package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.EntityAccessorMacro.build()) class EntityAccessorMacro<World, Rest> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [world, terms]):
            var baseName = MacroUtils.getBaseName(world);
            var simpleTermInfo = TermUtils.parseSimpleTerms(world, terms);
            var name = 'EntityAccessor${baseName}_${simpleTermInfo.structureId}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () ->
                generateEntityAccessor(name, world, terms, simpleTermInfo));
        case _:
            Context.error("EntityAccessorMacro requires exactly two type parameters", Context.currentPos());
    }
}

function generateEntityAccessor(name:String, world:Type, terms:Type,
        simpleTermInfo:TermUtils.SimpleTermInfo):Array<TypeDefinition> {
    final pos = Context.currentPos();

    var accessorFields:Array<Field> = [];
    var constructorArgs = [
        { name: "world", type: TypeTools.toComplexType(world) },
        { name: "eid", type: TPath({ pack: [], name: "Int" }) }
    ];

    // Store world and eid
    accessorFields.push({
        name: "_world",
        kind: FVar(TypeTools.toComplexType(world)),
        pos: pos,
        access: [APrivate, AFinal]
    });

    accessorFields.push({
        name: "_eid",
        kind: FVar(TPath({ pack: [], name: "Int" })),
        pos: pos,
        access: [APrivate, AFinal]
    });

    // Store component wrappers
    var componentWrappers:Array<{name:String, wrapperType:ComplexType, pattern:MacroUtils.ComponentPattern}> = [];

    for (termInfo in simpleTermInfo.allComponents) {
        var pattern = MacroUtils.analyzeComponentType(termInfo.componentType);
        var wrapperType:ComplexType = TPath({
            pack: ['hxbitecs'],
            name: 'ComponentWrapperMacro',
            params: [TPType(TypeTools.toComplexType(termInfo.componentType))]
        });

        componentWrappers.push({
            name: termInfo.name,
            wrapperType: wrapperType,
            pattern: pattern
        });

        // Add component wrapper field
        accessorFields.push({
            name: '_${termInfo.name}',
            kind: FVar(wrapperType),
            pos: pos,
            access: [APrivate, AFinal]
        });
    }

    // Constructor - directly create component wrappers without dummy query
    var constructorExprs = [
        macro this._world = world,
        macro this._eid = eid
    ];

    for (wrapper in componentWrappers) {
        var fieldName = wrapper.name;
        var wrapperTypePath = switch wrapper.wrapperType {
            case TPath(p): p;
            case _: Context.error('Unexpected wrapper type for $fieldName', pos);
        };

        var privateFieldName = '_$fieldName';
        switch wrapper.pattern {
            case SoA(_) | AoS(_):
                // For SoA and AoS, create wrapper with store and eid directly from world
                constructorExprs.push(macro this.$privateFieldName = new $wrapperTypePath({
                    store: world.$fieldName,
                    eid: eid
                }));
            case Tag:
                // For tag components, just pass the eid
                constructorExprs.push(macro this.$privateFieldName = new $wrapperTypePath(eid));
        }
    }

    var constructor:Field = {
        name: "new",
        kind: FFun({
            args: constructorArgs,
            ret: null,
            expr: { expr: EBlock(constructorExprs), pos: pos }
        }),
        pos: pos,
        access: [APublic, AInline]
    };
    accessorFields.push(constructor);

    // Add eid getter for convenience
    accessorFields.push({
        name: "eid",
        kind: FProp("get", "never", TPath({ pack: [], name: "Int" })),
        pos: pos,
        access: [APublic]
    });

    accessorFields.push({
        name: "get_eid",
        kind: FFun({
            args: [],
            ret: TPath({ pack: [], name: "Int" }),
            expr: macro return this._eid
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    // Add component access properties
    for (wrapper in componentWrappers) {
        var fieldName = wrapper.name;

        // Add property
        accessorFields.push({
            name: fieldName,
            kind: FProp("get", "never", wrapper.wrapperType),
            pos: pos,
            access: [APublic]
        });

        // Add getter that returns the wrapper
        var privateFieldName = '_$fieldName';
        accessorFields.push({
            name: 'get_$fieldName',
            kind: FFun({
                args: [],
                ret: wrapper.wrapperType,
                expr: macro return this.$privateFieldName
            }),
            pos: pos,
            access: [APublic, AInline]
        });
    }

    var accessorDef:TypeDefinition = {
        name: name,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDClass(),
        fields: accessorFields
    };

    trace(new haxe.macro.Printer().printTypeDefinition(accessorDef));
    return [accessorDef];
}
#end

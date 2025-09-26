package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.TagWrapperMacro.build()) class TagWrapperMacro<T> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [componentType]):
            var pattern = MacroUtils.analyzeComponentType(componentType);

            switch pattern {
                case Tag:
                    var baseName = MacroUtils.getBaseName(componentType);
                    var name = 'TagWrapper_${baseName}';
                    var ct = TPath({ pack: ['hxbitecs'], name: name });

                    return MacroUtils.buildGenericType(name, ct, () ->
                        generateTagWrapper(name, componentType));
                case _:
                    Context.error('TagWrapperMacro only supports Tag component types', Context.currentPos());
            }
        case _:
            Context.error("TagWrapperMacro requires exactly one type parameter", Context.currentPos());
    }
}

function generateTagWrapper(name:String, componentType:Type):Array<TypeDefinition> {
    var pos = Context.currentPos();

    // For tag components, we just create a simple abstract over Int (the eid)
    // Since there's no actual data to access
    var wrapperFields:Array<Field> = [];

    // Constructor
    wrapperFields.push({
        name: "new",
        kind: FFun({
            args: [{ name: "eid", type: TPath({ pack: [], name: "Int" }) }],
            ret: null,
            expr: macro this = eid
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    return [{
        name: name,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDAbstract(TPath({ pack: [], name: "Int" })),
        fields: wrapperFields
    }];
}
#end
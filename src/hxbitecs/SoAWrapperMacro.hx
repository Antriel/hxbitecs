package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.SoAWrapperMacro.build()) class SoAWrapperMacro<T> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [componentType]):
            var pattern = MacroUtils.analyzeComponentType(componentType);

            switch pattern {
                case SoA(fields):
                    var baseName = MacroUtils.getBaseName(componentType);
                    var name = 'SoAWrapper_${baseName}';
                    var ct = TPath({ pack: ['hxbitecs'], name: name });

                    return MacroUtils.buildGenericType(name, ct, () ->
                        generateSoAWrapper(name, componentType, fields));
                case _:
                    Context.error('SoAWrapperMacro only supports SoA component types', Context.currentPos());
            }
        case _:
            Context.error("SoAWrapperMacro requires exactly one type parameter", Context.currentPos());
    }
}

function generateSoAWrapper(name:String, componentType:Type,
        fields:Array<{name:String, type:Type}>):Array<TypeDefinition> {
    var pos = Context.currentPos();

    // Create the underlying type: {store: ComponentType, eid: Int}
    var underlyingType:ComplexType = TAnonymous([
        {
            name: "store",
            kind: FVar(TypeTools.toComplexType(componentType)),
            pos: pos,
            access: []
        },
        {
            name: "eid",
            kind: FVar(TPath({ pack: [], name: "Int" })),
            pos: pos,
            access: []
        }
    ]);

    var wrapperFields:Array<Field> = [];

    // Constructor
    wrapperFields.push({
        name: "new",
        kind: FFun({
            args: [{ name: "v", type: underlyingType }],
            ret: null,
            expr: macro this = v
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    // Generate getter/setter properties for each field
    for (field in fields) {
        var fieldName = field.name;
        var fieldType = TypeTools.toComplexType(field.type);

        // Property declaration
        wrapperFields.push({
            name: fieldName,
            kind: FProp("get", "set", fieldType),
            pos: pos,
            access: [APublic]
        });

        // Getter
        wrapperFields.push({
            name: 'get_$fieldName',
            kind: FFun({
                args: [],
                ret: fieldType,
                expr: macro return this.store.$fieldName[this.eid]
            }),
            pos: pos,
            access: [APublic, AInline]
        });

        // Setter
        wrapperFields.push({
            name: 'set_$fieldName',
            kind: FFun({
                args: [{ name: "v", type: fieldType }],
                ret: fieldType,
                expr: macro return this.store.$fieldName[this.eid] = v
            }),
            pos: pos,
            access: [APublic, AInline]
        });
    }

    final td = {
        name: name,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDAbstract(underlyingType),
        fields: wrapperFields
    };
    trace(new haxe.macro.Printer().printTypeDefinition(td));
    return [td];
}
#end

package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.AoSWrapperMacro.build()) class AoSWrapperMacro<T> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [componentType]):
            var pattern = MacroUtils.analyzeComponentType(componentType);

            switch pattern {
                case AoS(elementType):
                    var baseName = MacroUtils.getBaseName(componentType);
                    var elementName = MacroUtils.getBaseName(elementType);
                    var name = 'AoSWrapper_${baseName}_${elementName}';
                    var ct = TPath({ pack: ['hxbitecs'], name: name });

                    return MacroUtils.buildGenericType(name, ct, () ->
                        generateAoSWrapper(name, componentType, elementType));
                case _:
                    Context.error('AoSWrapperMacro only supports AoS component types', Context.currentPos());
            }
        case _:
            Context.error("AoSWrapperMacro requires exactly one type parameter", Context.currentPos());
    }
}

function generateAoSWrapper(name:String, componentType:Type, elementType:Type):Array<TypeDefinition> {
    var pos = Context.currentPos();

    // Create the underlying type: {store: Array<ElementType>, eid: Int}
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

    // Generate getter/setter properties based on element type fields
    switch elementType {
        case TAnonymous(a):
            for (field in a.get().fields) {
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
                        expr: macro return this.store[this.eid].$fieldName
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
                        expr: macro return this.store[this.eid].$fieldName = v
                    }),
                    pos: pos,
                    access: [APublic, AInline]
                });
            }
        case _:
            Context.error('AoS element type must be anonymous structure', pos);
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

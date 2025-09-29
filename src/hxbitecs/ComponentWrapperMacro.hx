package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.ComponentWrapperMacro.build()) class ComponentWrapperMacro<T> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [componentType]):
            var pattern = MacroUtils.analyzeComponentType(componentType);
            var baseName = MacroUtils.getBaseName(componentType);
            var pos = Context.currentPos();

            var name = switch pattern {
                case SoA(_): 'SoAWrapper_${baseName}';
                case AoS(elementType):
                    var elementName = MacroUtils.getBaseName(elementType);
                    'AoSWrapper_${baseName}_${elementName}';
                case SimpleArray(elementType):
                    var elementName = MacroUtils.getBaseName(elementType);
                    'SimpleArrayWrapper_${baseName}_${elementName}';
                case Tag: 'TagWrapper_${baseName}';
            };

            var ct = TPath({ pack: ['hxbitecs'], name: name });
            return MacroUtils.buildGenericType(name, ct, () -> switch pattern {
                case SoA(fields):
                    generateStoreWrapper(name, componentType, fields, generateSoAAccess);
                case AoS(elementType):
                    var fields = extractAoSFields(elementType);
                    generateStoreWrapper(name, componentType, fields, generateAoSAccess);
                case SimpleArray(elementType):
                    throw "Should be handled at entity level";
                case Tag:
                    generateTagWrapper(name, componentType);
            });
        case _:
            Context.error("ComponentWrapperMacro requires exactly one type parameter", Context.currentPos());
    }
}

function extractAoSFields(elementType:Type):Array<{name:String, type:Type}> {
    return switch elementType {
        case TAnonymous(a):
            [for (field in a.get().fields) { name: field.name, type: field.type }];
        case _:
            Context.error('AoS element type must be anonymous structure', Context.currentPos());
    };
}

function generateSoAAccess(fieldName:String):Expr {
    return macro this.store.$fieldName[this.eid];
}

function generateAoSAccess(fieldName:String):Expr {
    return macro this.store[this.eid].$fieldName;
}

function generateStoreWrapper(name:String, componentType:Type, fields:Array<{name:String, type:Type}>,
        accessGenerator:(fieldName:String) -> Expr):Array<TypeDefinition> {
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
                expr: { expr: EReturn(accessGenerator(fieldName)), pos: pos }
            }),
            pos: pos,
            access: [APublic, AInline]
        });

        // Setter
        var setterExpr = switch accessGenerator(fieldName).expr {
            case EField(obj, field): { expr: EBinop(OpAssign, { expr: EField(obj, field), pos: pos }, macro v), pos: pos };
            case EArray(obj, index): { expr: EBinop(OpAssign, { expr: EArray(obj, index), pos: pos }, macro v), pos: pos };
            case _: Context.error('Unsupported access pattern', pos);
        };

        wrapperFields.push({
            name: 'set_$fieldName',
            kind: FFun({
                args: [{ name: "v", type: fieldType }],
                ret: fieldType,
                expr: { expr: EReturn(setterExpr), pos: pos }
            }),
            pos: pos,
            access: [APublic, AInline]
        });
    }

    return [createWrapperTypeDefinition(name, underlyingType, wrapperFields)];
}

function generateTagWrapper(name:String, componentType:Type):Array<TypeDefinition> {
    var pos = Context.currentPos();
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
function createWrapperTypeDefinition(name:String, underlyingType:ComplexType,
        fields:Array<Field>):TypeDefinition {
    var pos = Context.currentPos();
    var td = {
        name: name,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDAbstract(underlyingType),
        fields: fields
    };
    trace(new haxe.macro.Printer().printTypeDefinition(td));
    return td;
}
#end

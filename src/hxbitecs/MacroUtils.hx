package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

@:persistent private var generated = new Map<String, Bool>();

function isGenerated(name:String):Bool {
    return generated.exists(name);
}

function setGenerated(name:String):Void {
    generated.set(name, true);
}

function isAlive(ct:ComplexType, pos:Position):Bool {
    return try Context.resolveType(ct, pos) != null catch (e) false;
}

function getBaseName(type:Type):String {
    return switch type {
        case TType(t, _): t.get().name;
        case TInst(t, _): t.get().name;
        case TAbstract(t, _): t.get().name; // Handle primitive types like Int, Float, Bool, etc.
        case TAnonymous(a): [for (f in a.get().fields) f.name].join('_');
        case _: Context.error('Unsupported type $type for `getBaseName`.', Context.currentPos());
    }
}

function getTypeFields(type:Type):Array<String> {
    return switch type {
        case TAnonymous(a):
            var fields = [];
            for (field in a.get().fields) {
                fields.push(field.name);
            }
            fields;
        case TInst(t, _):
            t.get().fields.get().map(f -> f.name);
        case TType(t, _):
            getTypeFields(t.get().type);
        case _:
            Context.error('Unsupported type $type for field extraction', Context.currentPos());
    }
}

function buildGenericType(name:String, ct:ComplexType, generator:() -> Array<TypeDefinition>):ComplexType {
    if (isGenerated(name)) {
        if (isAlive(ct, Context.currentPos())) {
            // Sys.println('Type $name already generated and alive.');
            return ct;
        }
        // Sys.println('Type $name already generated but dead.');
    } else {
        // Sys.println('Type $name not yet generated.');
    }

    final types = generator();
    Context.defineModule('hxbitecs.$name', types);
    setGenerated(name);
    return ct;
}

enum ComponentPattern {

    SoA(fields:Array<{name:String, type:Type}>); // Structure of Arrays: {x:Array<T>, y:Array<T>}
    AoS(elementType:Type); // Array of Structs: Array<{...}>
    SimpleArray(elementType:Type); // Simple Array: Array<Int>, Float32Array, etc.
    Tag; // Empty object: {}

}

function analyzeComponentType(type:Type):ComponentPattern {
    return switch type {
        case TAnonymous(a):
            var fields = a.get().fields;
            if (fields.length == 0) {
                Tag;
            } else {
                // Check if all fields are arrays (SoA pattern)
                var soaFields = [];
                var allArrays = true;
                for (field in fields) {
                    switch field.type {
                        case TInst(_.get() => { name: "Array" }, [elementType]):
                            soaFields.push({ name: field.name, type: elementType });
                        case _:
                            allArrays = false;
                            break;
                    }
                }
                if (allArrays) {
                    SoA(soaFields);
                } else {
                    Context.error('Unsupported anonymous component structure: $type', Context.currentPos());
                }
            }
        case TInst(_.get() => { name: "Array" }, [elementType]):
            // Distinguish between Array<{...}> (AoS) and Array<primitive> (SimpleArray)
            switch elementType {
                case TAnonymous(_): AoS(elementType); // Array of anonymous structures
                case _: SimpleArray(elementType); // Array of primitives
            }
        case TInst(_.get() => { name: typeName }, _) if (isTypedArray(typeName)):
            // JS typed arrays: Float32Array, Int32Array, etc.
            var elementType = getTypedArrayElementType(typeName);
            SimpleArray(elementType);
        case _:
            Context.error('Unsupported component type: $type', Context.currentPos());
    }
}

typedef ComponentFieldInfo = {

    name:String,
    type:Type,
    complexType:ComplexType

}

function getComponentFields(componentType:Type):Array<ComponentFieldInfo> {
    return switch analyzeComponentType(componentType) {
        case SoA(fields):
            [for (field in fields) {
                name: field.name,
                type: field.type,
                complexType: TypeTools.toComplexType(field.type)
            }];
        case AoS(elementType):
            switch elementType {
                case TAnonymous(a):
                    [for (field in a.get().fields) {
                        name: field.name,
                        type: field.type,
                        complexType: TypeTools.toComplexType(field.type)
                    }];
                case _:
                    Context.error('AoS element type must be anonymous structure', Context.currentPos());
            }
        case SimpleArray(elementType):
            []; // Simple arrays have no named fields - direct array access
        case Tag:
            [];
    }
}

function isTypedArray(typeName:String):Bool {
    return switch typeName {
        case "Int8Array" | "Uint8Array" | "Uint8ClampedArray" |
             "Int16Array" | "Uint16Array" |
             "Int32Array" | "Uint32Array" |
             "Float32Array" | "Float64Array" |
             "BigInt64Array" | "BigUint64Array": true;
        case _: false;
    }
}

function getTypedArrayElementType(typeName:String):Type {
    return switch typeName {
        case "Int8Array" | "Int16Array" | "Int32Array" | "Uint8Array" | "Uint16Array" | "Uint32Array" | "Uint8ClampedArray":
            Context.getType("Int");
        case "Float32Array" | "Float64Array":
            Context.getType("Float");
        case "BigInt64Array" | "BigUint64Array":
            Context.getType("haxe.Int64"); // or appropriate big int type
        case _:
            Context.error('Unknown typed array: $typeName', Context.currentPos());
    }
}

function generatePropertyWithGetSet(propertyName:String, propertyType:ComplexType,
        getterExpr:Expr, setterExpr:Expr):Array<Field> {
    var pos = Context.currentPos();
    var fields:Array<Field> = [];

    // Property declaration
    fields.push({
        name: propertyName,
        kind: FProp("get", "set", propertyType),
        pos: pos,
        access: [APublic]
    });

    // Getter method
    fields.push({
        name: 'get_$propertyName',
        kind: FFun({
            args: [],
            ret: propertyType,
            expr: { expr: EReturn(getterExpr), pos: pos }
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    // Setter method
    fields.push({
        name: 'set_$propertyName',
        kind: FFun({
            args: [{ name: "v", type: propertyType }],
            ret: propertyType,
            expr: { expr: EReturn(setterExpr), pos: pos }
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    return fields;
}

function generateSimpleArrayAccessExprs(arrayRef:Expr, eid:Expr):{get:Expr, set:Expr} {
    var pos = Context.currentPos();
    return {
        get: { expr: EArray(arrayRef, eid), pos: pos },
        set: { expr: EBinop(OpAssign, { expr: EArray(arrayRef, eid), pos: pos }, macro v), pos: pos }
    };
}

#end

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
            AoS(elementType);
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
        case Tag:
            [];
    }
}

#end

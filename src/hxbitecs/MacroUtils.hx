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
        case TAnonymous(a):
            "Anon_" + haxe.macro.PositionTools.toLocation(Context.currentPos()).range.start.line;
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

function buildGenericType(name:String, ct:ComplexType, generator:() -> TypeDefinition):ComplexType {
    if (isGenerated(name)) {
        if (isAlive(ct, Context.currentPos())) {
            return ct;
        }
    }

    final td = generator();
    td.name = name;
    Context.defineType(td);
    setGenerated(name);
    return ct;
}
#end

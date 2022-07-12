package bitecs;

import haxe.macro.Expr;
import haxe.macro.Type;

using tink.MacroApi;

function getDefinition(t:Type) {
    // TODO allow specifying precision via metadata.
    var objFields:Array<ObjectField> = [];
    for (field in t.getFields().sure()) {
        final bitEcsType = switch field.type.reduce() {
            case TAbstract(t, params):
                if (params.length > 0) throw "unexpected";
                switch t.get().name {
                    case 'Float': macro bitecs.Bitecs.Types.f64;
                    case 'Int': macro bitecs.Bitecs.Types.i32;
                    case 'Bool': macro bitecs.Bitecs.Types.ui8;
                    case _: throw "unexpected";
                }
            case _: throw "not implemented";
        }
        // TODO positions?
        objFields.push({
            field: field.name,
            expr: bitEcsType
        });
    }
    return EObjectDecl(objFields).at();
}

package bitecs;

import haxe.macro.Expr;
import haxe.macro.Type;

using tink.MacroApi;

function getDefinition(t:Type) {
    var objFields:Array<ObjectField> = [];
    for (field in t.getFields().sure()) {
        var meta = field.meta.extract(':bitecs.type')[0];
        var precision = meta == null ? null : meta.params[0].toString();
        // TODO check if precision is valid for the type?
        switch field.type.reduce() {
            case TAbstract(t, params):
                if (params.length > 0) throw "unexpected";
                switch t.get().name {
                    case 'Float':
                        if (precision == null) precision = 'f64';
                    case 'Int': if (precision == null) precision = 'i32';
                    case 'Bool': if (precision == null) precision = 'ui8';
                    case _: throw "unexpected";
                }
            case _: throw "not implemented";
        }
        var bitEcsType = macro @:pos(field.pos) bitecs.Bitecs.Types.$precision;
        objFields.push({
            field: field.name,
            expr: bitEcsType
        });
    }
    return EObjectDecl(objFields).at(t.getPosition().sure());
}

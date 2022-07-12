package bitecs;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

using tink.MacroApi;

function getDefinition(t:Type) {
    // TODO support `eid` type.
    final typePos = t.getPosition().sure();
    var objFields:Array<ObjectField> = [];
    var mappedFields = [];
    for (field in t.getFields().sure()) {
        switch field.type.reduce() {
            case TAbstract(t, params):
                var meta = field.meta.extract(':bitecs.type')[0];
                var precision = meta == null ? null : meta.params[0].toString();
                // TODO check if precision is valid for the type?
                if (params.length > 0) throw "unexpected";
                switch t.get().name {
                    case 'Float':
                        if (precision == null) precision = 'f64';
                    case 'Int': if (precision == null) precision = 'i32';
                    case 'Bool': if (precision == null) precision = 'ui8';
                    case _: throw "unexpected";
                }
                var bitEcsType = macro @:pos(field.pos) bitecs.Bitecs.Types.$precision;
                objFields.push({
                    field: field.name,
                    expr: bitEcsType
                });
            case _:
                // var ct = TypeTools.toComplexType(field.type); // TODO typing it all.
                mappedFields.push({ name: field.name });
        }
    }
    final init = macro @:pos(typePos) Bitecs.defineComponent(${EObjectDecl(objFields).at(typePos)});
    if (mappedFields.length > 0) {
        var res = macro final c = $init;
        for (f in mappedFields) {
            var name = f.name;
            res = res.concat((macro c.$name).assign(macro new js.lib.Map()));
        }
        res = res.concat(macro c);
        return res;
    } else return init;
}

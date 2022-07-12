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
    var typeFields = [];
    for (field in t.getFields().sure()) {
        var typeField = {
            name: field.name,
            pos: field.pos,
            kind: null,
            doc: field.doc
        };
        typeFields.push(typeField);
        final ct = TypeTools.toComplexType(field.type);
        switch field.type.reduce() {
            case TAbstract(t, params):
                if (params.length > 0) throw "unexpected";
                var meta = field.meta.extract(':bitecs.type')[0];
                var typeName = meta == null ? null : meta.params[0].toString();
                // TODO check if provided type name is valid for the actual field type?
                if (typeName == null) typeName = switch t.get().name {
                    case 'Float': 'f64';
                    case 'Int': 'i32';
                    case 'Bool': 'ui8';
                    case _: throw "unexpected";
                }
                var bitEcsType = Lambda.find(bitEcsTypeToCT, t -> t.names.contains(typeName));
                if (bitEcsType == null) haxe.macro.Context.error('Failed to determine bitECS type.', field.pos);
                objFields.push({
                    field: field.name,
                    expr: bitEcsType.expr.expr.at(field.pos)
                });
                typeField.kind = FieldType.FVar(bitEcsType.ct);
            case _:
                mappedFields.push({ name: field.name });
                typeField.kind = FieldType.FVar(macro:js.lib.Map<bitecs.Entity, $ct>);
        }
    }
    var expr = macro @:pos(typePos) Bitecs.defineComponent(${EObjectDecl(objFields).at(typePos)});
    if (mappedFields.length > 0) {
        expr = macro final c = $expr;
        for (f in mappedFields) {
            var name = f.name;
            expr = expr.concat((macro c.$name).assign(macro new js.lib.Map()));
        }
        expr = expr.concat(macro c);
    };

    return FieldType.FVar(TAnonymous(typeFields), expr);
}

private var bitEcsTypeToCT = [
    { names: ['i8', 'int8'], ct: macro:js.lib.Int8Array, expr: macro bitecs.Bitecs.Types.i8 },
    { names: ['ui8', 'uint8'], ct: macro:js.lib.Uint8Array, expr: macro bitecs.Bitecs.Types.ui8 },
    { names: ['ui8c'], ct: macro:js.lib.Uint8ClampedArray, expr: macro bitecs.Bitecs.Types.ui8c },
    { names: ['i16', 'int16'], ct: macro:js.lib.Int16Array, expr: macro bitecs.Bitecs.Types.i16 },
    { names: ['ui16', 'uint16'], ct: macro:js.lib.Uint16Array, expr: macro bitecs.Bitecs.Types.ui16 },
    { names: ['i32', 'int32'], ct: macro:js.lib.Int32Array, expr: macro bitecs.Bitecs.Types.i32 },
    { names: ['ui32', 'uint32'], ct: macro:js.lib.Uint32Array, expr: macro bitecs.Bitecs.Types.ui32 },
    { names: ['f32', 'float32'], ct: macro:js.lib.Float32Array, expr: macro bitecs.Bitecs.Types.f32 },
    { names: ['f64', 'float64'], ct: macro:js.lib.Float64Array, expr: macro bitecs.Bitecs.Types.f64 },
    { names: ['eid', 'entity'], ct: macro:js.lib.Uint32Array, expr: macro bitecs.Bitecs.Types.eid },
];

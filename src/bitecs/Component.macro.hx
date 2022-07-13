package bitecs;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

using tink.MacroApi;

@:persistent private var usedNames:Map<String, Int> = [];

function getDefinition(t:Type):CompDef {
    // TODO support `eid` type.
    final typePos = t.getPosition().sure();
    final compName = {
        var n = t.getID().split('.').pop();
        if (usedNames.exists(n)) {
            final i = usedNames.get(n) + 1;
            usedNames.set(n, i);
            n + i;
        } else {
            usedNames.set(n, 0);
            n;
        }
    };

    var objFields:Array<ObjectField> = [];
    var mappedFields = [];
    var typeFields = [];
    var wrapperFields:Array<Field> = [];
    var initFieldExprs = [];
    for (field in t.getFields().sure()) {
        final fname = field.name;
        var typeField = {
            name: fname,
            pos: field.pos,
            kind: null,
            doc: field.doc
        };
        typeFields.push(typeField);
        final ct = TypeTools.toComplexType(field.type);
        var modValueGet:Expr->Expr = e -> e; // Identity by default.
        var modValueSet:Expr->Expr = e -> e;
        final isMap = switch field.type.reduce() {
            case TAbstract(t, params):
                if (params.length > 0) throw "unexpected";
                var meta = field.meta.extract(':bitecs.type')[0];
                var typeName = meta == null ? null : meta.params[0].toString();
                // TODO check if provided type name is valid for the actual field type?
                if (typeName == null) typeName = switch t.get().name {
                    case 'Float': 'f64';
                    case 'Int': 'i32';
                    case 'Bool':
                        modValueGet = e -> macro $e > 0;
                        modValueSet = e -> macro if ($e) 1 else 0;
                        'ui8';
                    case _: throw "unexpected";
                }
                var bitEcsType = Lambda.find(bitEcsTypeToCT, t -> t.names.contains(typeName));
                if (bitEcsType == null) haxe.macro.Context.error('Failed to determine bitECS type.', field.pos);
                objFields.push({
                    field: fname,
                    expr: bitEcsType.expr.expr.at(field.pos)
                });
                typeField.kind = FieldType.FVar(bitEcsType.ct);
                false;
            case _:
                mappedFields.push({ name: fname });
                typeField.kind = FieldType.FVar(macro:js.lib.Map<bitecs.Entity, $ct>);
                true;
        }
        var texpr = field.expr();
        if (texpr != null) {
            final initVal = haxe.macro.Context.getTypedExpr(texpr);
            initFieldExprs.push(macro comp.$fname = $initVal); // `comp` is parameter of the `init` function.
        }

        wrapperFields.push({
            name: fname,
            pos: field.pos,
            kind: FProp('get', 'set', ct),
            doc: field.doc,
            access: [APublic]
        });
        wrapperFields.push({
            name: 'get_$fname',
            pos: field.pos,
            kind: FFun({
                args: [],
                expr: EReturn(modValueGet((isMap ? macro this.store.$fname.get(this.ent) : macro this.store.$fname[this.ent]))).at()
            }),
            access: [AInline]
        });
        wrapperFields.push({
            name: 'set_$fname',
            pos: field.pos,
            kind: FFun({
                args: [{ name: 'v' }],
                expr: {
                    var val = modValueSet(macro v);
                    var setter = isMap ? macro this.store.$fname.set(this.ent, $val) : macro this.store.$fname[this.ent] = $val;
                    macro return {
                        $setter;
                        v;
                    }
                }
            }),
            access: [AInline]
        });
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

    final storeType = ComplexType.TAnonymous(typeFields);
    final wrapperPath = { pack: ['bitecs', 'gen'], name: compName };

    // The init function – sets the defaults, if any.
    wrapperFields.push({
        name: 'init',
        pos: typePos,
        kind: FFun({
            args: [{ name: 'comp', type: TPath(wrapperPath) }],
            ret: voidType,
            expr: initFieldExprs.toBlock(typePos)
        }),
        access: [APublic, AStatic, AInline], // Static, but also enabled via `@:using`.
        doc: 'Sets the component values to their defaults.'
    });

    final wrapperTd:TypeDefinition = {
        pack: wrapperPath.pack,
        name: wrapperPath.name,
        pos: typePos,
        meta: [{ name: ':using', params: [['bitecs', 'gen', compName].drill()], pos: typePos }],
        kind: TDAbstract(TAnonymous([
            { name: 'ent', kind: FVar(entityType), pos: typePos },
            { name: 'store', kind: FVar(storeType), pos: typePos }
        ])),
        fields: wrapperFields.concat([
            {
                name: 'new',
                kind: FFun({
                    args: [{ name: 'ent' }, { name: 'store' }],
                    expr: macro this = { ent: ent, store: store }
                }),
                access: [APublic, AInline],
                pos: typePos
            }
        ])
    };

    return {
        instanceVar: FieldType.FVar(storeType, expr),
        wrapper: wrapperTd,
        wrapperPath: wrapperPath
    }
}

typedef CompDef = {

    instanceVar:FieldType,
    wrapper:TypeDefinition,
    wrapperPath:TypePath

}

private var worldType = macro:bitecs.World;
private var entityType = macro:bitecs.Entity;
private var voidType = macro:Void;

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

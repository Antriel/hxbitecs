package bitecs;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

using Lambda;
using tink.MacroApi;

@:persistent private var usedNames:Map<String, Int> = [];

function getDefinition(t:Type):ComponentDefinition {
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
    var extraFields = switch t.reduce() { // Find abstract fields to also copy.
        case TAbstract(t, params): t.get().impl.get().statics.get();
        case _: [];
    }
    var fields = Context.followWithAbstracts(t).getFields().sure().concat(extraFields);
    return new ComponentDefinition(compName, typePos, fields);
}

class ComponentDefinition {

    public var storeType:ComplexType;
    public var initExpr:Expr;
    public var wrapper:TypeDefinition;
    public var wrapperPath:TypePath;

    final name:String;
    final typePos:Position;
    final compFields:Array<{

        /** The field that needs to exist on the actual component storage. */
        var storeField:Field;

        /** The defition field used to create the bitECS store. */
        var storeDefField:ObjectField;

        var type:CompFieldType;
        var ct:ComplexType;
        var initExpr:Expr;
        var mod:{valGet:Expr->Expr, valSet:Expr->Expr};
    }> = [];
    final funFields:Array<Field> = [];

    public function new(name:String, typePos:Position, fields:Array<ClassField>) {
        this.name = name;
        this.typePos = typePos;
        for (f in fields) processField(f);
        buildWrapper();
    }

    function processField(field:ClassField) {
        var mod = { valGet: null, valSet: null }; // Conversion of value to/from the stored type.
        switch field.type.reduce() {
            case TAbstract(t, params):
                if (params.length > 0) throw "unexpected";
                var meta = field.meta.extract(':bitecs.type')[0];
                // TODO check if provided type name is valid for the actual field type?
                var typeName = meta == null ? null : meta.params[0].toString();
                // Look further down the abstract type, to handle custom abstracts.
                if (typeName == null) typeName = switch t.get().type.reduce() {
                    case TAbstract(_.get().name => name, params): switch name {
                            case 'Float': 'f64';
                            case 'Int': 'i32';
                            case 'Bool':
                                mod.valGet = e -> macro $e > 0;
                                mod.valSet = e -> macro if ($e) 1 else 0;
                                'ui8';
                            case _:
                                Context.error('Could not process component field type.', field.pos);
                        }
                    case _: // Abstract over some instance type.
                        addCompField(Mapped, field, mod);
                        return;
                }
                addCompField(BitECS(typeName), field, mod);
            case TFun(args, ret):
                var expr = Context.getTypedExpr(field.expr());
                var func = switch expr.expr {
                    case EFunction(kind, f): f;
                    case _: Context.error("Expected EFunction.", expr.pos);
                }
                func.expr = replaceThis(func.expr);
                var access:Array<Access> = [];
                if (field.isPublic) access.push(APublic);
                switch field.kind {
                    case FMethod(k): switch k {
                            case MethNormal:
                            case MethInline: access.push(AInline);
                            case MethDynamic: Context.error('Unsupported method type.', field.pos);
                            case MethMacro: access.push(AMacro);
                        }
                    case _: throw "unexpected";
                }
                // Remove `this` arg. (Comes from extra static fields of the Abstract implementation type.)
                func.args = func.args.filter(a -> a.name != 'this');
                funFields.push({
                    name: field.name,
                    doc: field.doc,
                    access: access,
                    kind: FFun(func),
                    pos: field.pos,
                    meta: field.meta.get()
                });
            case _:
                addCompField(Mapped, field, mod);
        }
    }

    function addCompField(type:CompFieldType, field:ClassField, mod:{valGet:Expr->Expr, valSet:Expr->Expr}) {
        var storeDefField = null;
        final ct = TypeTools.toComplexType(field.type);
        final storeField = {
            name: field.name,
            pos: field.pos,
            kind: switch type {
                case BitECS(typeName):
                    var bitEcsType = bitEcsTypeToCT.find(t -> t.names.contains(typeName));
                    if (bitEcsType == null) haxe.macro.Context.error('Failed to determine bitECS type.', field.pos);
                    storeDefField = {
                        field: field.name,
                        expr: bitEcsType.expr.expr.at(field.pos)
                    };
                    FieldType.FVar(bitEcsType.ct);
                case Mapped:
                    FieldType.FVar(macro:js.lib.Map<bitecs.Entity, $ct>);
            },
            doc: field.doc
        };

        var initExpr = null;
        var texpr = field.expr();
        if (texpr != null) {
            final initVal = haxe.macro.Context.getTypedExpr(texpr);
            final fname = field.name;
            initExpr = macro comp.$fname = $initVal; // `comp` is parameter of the `init` function.
        }

        compFields.push({
            storeField: storeField,
            storeDefField: storeDefField,
            type: type,
            ct: ct,
            initExpr: initExpr,
            mod: mod
        });
    }

    function buildWrapper() {
        var wrapperFields:Array<Field> = [];
        for (field in compFields) {
            final fname = field.storeField.name;
            final prop = Member.prop(fname, field.ct, field.storeField.pos);
            prop.publish();
            wrapperFields.push(prop);
            var valExpr = macro v;
            if (field.mod.valSet != null) valExpr = field.mod.valSet(valExpr);
            var propExprs = switch field.type {
                case BitECS(_):
                    {
                        getter: macro this.store.$fname[this.ent],
                        setter: macro this.store.$fname[this.ent] = $valExpr,
                    }
                case Mapped:
                    {
                        getter: macro this.store.$fname.get(this.ent),
                        setter: macro this.store.$fname.set(this.ent, $valExpr),
                    }
            }
            if (field.mod.valGet != null) propExprs.getter = field.mod.valGet(propExprs.getter);
            var getter = Member.getter(fname, field.storeField.pos, propExprs.getter);
            getter.isBound = true;
            wrapperFields.push(getter);
            var setter = Member.setter(fname, 'v', field.storeField.pos, propExprs.setter);
            setter.isBound = true;
            wrapperFields.push(setter);
        }
        var defObjFields = compFields.map(f -> f.storeDefField).filter(f -> f != null);
        initExpr = macro @:pos(typePos) Bitecs.defineComponent(${EObjectDecl(defObjFields).at(typePos)});
        if (compFields.exists(f -> f.type.match(Mapped))) {
            initExpr = macro final c = $initExpr;
            for (f in compFields) if (f.type.match(Mapped)) {
                var name = f.storeField.name;
                initExpr = initExpr.concat((macro c.$name).assign(macro new js.lib.Map()));
            }
            initExpr = initExpr.concat(macro c);
        };

        storeType = ComplexType.TAnonymous(compFields.map(f -> f.storeField));
        wrapperPath = { pack: ['bitecs', 'gen'], name: name };

        // The init function – sets the defaults, if any.
        var initFieldExprs = compFields.map(f -> f.initExpr).filter(e -> e != null);
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

        for (f in funFields) wrapperFields.push(f);

        wrapper = {
            pack: wrapperPath.pack,
            name: wrapperPath.name,
            pos: typePos,
            meta: [{ name: ':using', params: [['bitecs', 'gen', name].drill()], pos: typePos }],
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

        // trace(new haxe.macro.Printer().printTypeDefinition(wrapper));
    }

}

private enum CompFieldType {

    BitECS(typeName:String);
    Mapped;

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

private function replaceThis(e:Expr):Expr {
    return switch e.expr {
        case EField({ expr: EConst(CIdent("this")) }, field):
            { expr: EConst(CIdent(field)), pos: e.pos };
        case _: ExprTools.map(e, replaceThis);
    }
}

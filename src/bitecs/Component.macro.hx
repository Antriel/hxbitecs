package bitecs;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

using Lambda;
using tink.MacroApi;

typedef ComponentExprs = {

    var fields:Array<Field>;
    var usings:Array<ClassType>;

}

@:persistent var cache:TypeMap<ComponentExprs> = new TypeMap();

function cacheExprs() {
    var fields = Context.getBuildFields();
    var t = Context.getLocalType();
    cache.set(t, {
        fields: fields,
        usings: Context.getLocalUsing().map(_ -> _.get()),
    });
    return []; // Keep the actual class empty.
}

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
    final actualType = Context.followWithAbstracts(t);
    final cached = cache.get(actualType);
    if (cached == null) Context.error("Type does not extend from bitecs.Component.", typePos);
    final def = new ComponentDefinition(compName, typePos, cached);
    def.buildWrapper();
    def.exactName = t.toExactString();
    return def;
}

class ComponentDefinition {

    public var storeType:ComplexType;
    public var initExpr:Expr;
    public var wrapper:TypeDefinition;
    public var wrapperPath:TypePath;
    public var initExtraArgs:Array<FunctionArg> = [];
    public var exactName:String;

    final name:String;
    final typePos:Position;
    final source:ComponentExprs;
    final compFields:Array<{

        /** The field that needs to exist on the actual component storage. */
        var storeField:Field;

        /** The defition field used to create the bitECS store. */
        var storeDefField:ObjectField;

        var type:CompFieldType;
        var ct:ComplexType;
        var initExpr:Expr;
        var mod:{valGet:Expr->Expr, valSet:Expr->Expr};
        var writable:Bool;
    }> = [];
    final funFields:Array<Field> = [];
    final initExtraExpr:Array<Expr> = [];

    public function new(name:String, typePos:Position, source:ComponentExprs) {
        this.name = name;
        this.typePos = typePos;
        this.source = source;
        for (f in source.fields) processField(f);
    }

    public function customCtr(ctr:Field, f:Function):Void {
        if (f.expr != null) {
            for (a in f.args) initExtraArgs.push(a);
            initExtraExpr.push(replaceThis(f.expr, macro comp)); // `comp` is parameter of the `init` function.
        }
    }

    function processField(field:Field) {
        var mod = { valGet: null, valSet: null }; // Conversion of value to/from the stored type.
        var typeMeta = field.meta.find(m -> m.name == ':bitecs.type');
        switch field.kind {
            case FProp('default', 'null', ct, e) | FVar(ct, e):
                if (ct == null) Context.error('Type not specified.', field.pos);
                var t = ComplexTypeTools.toType(ct);
                switch TypeTools.follow(t, true) {
                    case TAbstract(_.get().name == "Null" => true, _):
                        Context.error('Nullable types are not supported.', field.pos);
                    case _:
                }
                final compFieldType = switch Context.followWithAbstracts(t) {
                    case TAbstract(_.get().name => name, params):
                        final typeName = if (typeMeta != null) typeMeta.params[0].toString()
                        else switch name {
                            case 'Float': 'f64';
                            case 'Int': 'i32';
                            case 'Bool':
                                mod.valGet = e -> macro $e > 0;
                                mod.valSet = e -> macro if ($e) 1 else 0;
                                'ui8';
                            case _:
                                Context.error('Could not process component field type.', field.pos);
                        }
                        BitECS(typeName);
                    case _:
                        Mapped;
                }
                final writable = !field.access.contains(AFinal) && !field.kind.match(FProp(_, 'null', _));
                addCompField(compFieldType, mod, writable, e, field);
            case FFun(f):
                if (field.name == 'new') {
                    customCtr(field, f);
                } else {
                    f.expr = replaceThis(f.expr);
                    funFields.push(field);
                }
            case FProp('get', _) | FProp(_, 'set', _):
                Context.error('Custom getter/setter is not supported. Use an explicit function.', field.pos);
            case _: Context.error("Failed to process field.", field.pos);
        }
    }

    function addCompField(type:CompFieldType, mod:{valGet:Expr->Expr, valSet:Expr->Expr}, writable:Bool, expr:Expr, field:Field) {
        var storeDefField = null;
        final ct = switch field.kind {
            case FVar(t, _) | FProp(_, _, t): t;
            case _: throw "unexpected";
        };
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
        if (expr != null) {
            var fname = field.name;
            if (!writable) fname = '_' + fname;
            initExpr = macro comp.$fname = $expr; // `comp` is parameter of the `init` function.
        }

        compFields.push({
            storeField: storeField,
            storeDefField: storeDefField,
            type: type,
            ct: ct,
            initExpr: initExpr,
            mod: mod,
            writable: writable
        });
    }

    public function buildWrapper() {
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
            if (!field.writable) {
                final privateName = '_' + prop.name;
                for (func in funFields) switch func.kind {
                    case FFun(f):
                        f.expr = replaceIdent(prop.name, f.expr, macro $i{privateName});
                    case _: throw 'unexpected';
                }
                for (i => e in initExtraExpr) initExtraExpr[i] = replaceField(prop.name, e, privateName);
                prop.name = privateName;
                setter.name = 'set_' + privateName;
                getter.name = 'get_' + privateName;
                prop.isPublic = false;
                final publicProp = Member.prop(fname, field.ct, field.storeField.pos);
                publicProp.publish();
                publicProp.kind = switch publicProp.kind {
                    case FProp(get, set, t, e): FProp(get, 'never', t, e);
                    case _: throw "unexpected";
                }
                wrapperFields.push(publicProp);
                var publicGetter = Member.getter(fname, field.storeField.pos, macro return $i{privateName});
                publicGetter.isBound = true;
                wrapperFields.push(publicGetter);
            }
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
                args: [{ name: 'comp', type: TPath(wrapperPath) }].concat(initExtraArgs),
                ret: voidType,
                expr: initFieldExprs.concat(initExtraExpr).toBlock(typePos)
            }),
            access: [APublic, AStatic, AInline], // Static, but also enabled via `@:using`.
            doc: 'Sets the component values to their defaults.'
        });
        final selfCt = ComplexType.TPath(wrapperPath);
        var tthis = Member.method('tthis', false, ({ args: [], expr: macro return (cast this:$selfCt) }:Function));
        tthis.isBound = true;
        wrapperFields.push(tthis);

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

private function replaceThis(e:Expr, with:Expr = null):Expr {
    return replaceIdent('this', e, with != null ? with : macro tthis());
}

private function replaceIdent(ident:String, on:Expr, with:Expr):Expr {
    function replace(e:Expr) {
        return switch e.expr {
            case EConst(CIdent(_ == ident => true)): with;
            case _: ExprTools.map(e, replace);
        }
    }
    return replace(on);
}

private function replaceField(field:String, on:Expr, with:String):Expr {
    function replace(e:Expr) {
        return switch e.expr {
            case EField(e, _ == field => true): { expr: EField(e, with), pos: e.pos };
            case _: ExprTools.map(e, replace);
        }
    }
    return replace(on);
}

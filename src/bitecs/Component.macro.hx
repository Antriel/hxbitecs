package bitecs;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

using Lambda;
using tink.MacroApi;

typedef ComponentSource = {

    var fields:Array<SourceField>;
    var imports:Array<ImportExpr>;
    var usings:Array<TypePath>;

}

typedef SourceField = {

    var field:Field;
    var type:Null<Type>;
    var ct:ComplexType;

};

@:persistent var cache:TypeMap<ComponentSource> = new TypeMap();

function cacheExprs() {
    final pos = Context.currentPos();
    var fields = Context.getBuildFields();
    var t = Context.getLocalType();
    var classType = switch t.reduce(true) {
        case TInst(t, params): t.get();
        case _: Context.error("Should be a class.", Context.currentPos());
    }
    cache.set(t, {
        fields: fields.map(field -> {
            final type = switch field.kind {
                case FProp(_, _, ct, _) | FVar(ct, _):
                    if (ct == null) Context.error('Type not specified.', field.pos);
                    ComplexTypeTools.toType(ct);
                case _: null;
            }
            {
                field: field,
                type: type,
                ct: type == null ? null : type.toComplex()
            }
        }),
        imports: [
            { // Import all from the original package, as we generate the type in a different one.
                path: { var p = classType.module.split('.'); p.pop(); p.map(p -> {name: p, pos: pos }); },
                mode: IAll
            },
            { // Import original module too, in case there are some inner types.
                path: classType.module.split('.').map(p -> {name: p, pos: pos }),
                mode: INormal
            }
        ].concat(Context.getLocalImports()),
        usings: Context.getLocalUsing().map(ref -> {
            var classType = ref.get();
            {
                pack: classType.pack,
                name: classType.module,
                sub: classType.name,
                params: []
            };
        }),
    });
    return []; // Keep the actual class empty.
}

@:persistent private var usedNames:Map<String, Int> = [];

function getDefinition(t:Type):ComponentDefinition {
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
    actualType.getFields(); // Workaround for https://github.com/HaxeFoundation/haxe/issues/7905, probably...
    final cached = cache.get(actualType);
    if (cached == null) Context.error("Type does not implement `bitecs.IComponent`.", typePos);
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
    public var source:ComponentSource;

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
        var writable:Bool;
    }> = [];
    final funFields:Array<Field> = [];
    final initExtraExpr:Array<Expr> = [];

    public function new(name:String, typePos:Position, source:ComponentSource) {
        this.name = name;
        this.typePos = typePos;
        this.source = source;
        for (f in source.fields) processField(f);
    }

    function customCtr(ctr:Field, f:Function):Void {
        if (f.expr != null) {
            for (a in f.args) initExtraArgs.push(a);
            initExtraExpr.push(f.expr);
        }
    }

    function processField(src:SourceField) {
        final field = src.field;
        var mod = { valGet: null, valSet: null }; // Conversion of value to/from the stored type.
        var typeMeta = field.meta.find(m -> m.name == ':bitecs.type');
        var lengthMeta = field.meta.find(m -> m.name == ':bitecs.length');
        var typeName = if (typeMeta != null) typeMeta.params[0].toString() else null;
        function getArrLength() {
            if (lengthMeta == null || lengthMeta.params.length < 1)
                Context.error('Arrays require `@:bitecs.length(len)` metadata.', field.pos);
            var len = lengthMeta.params[0].eval();
            if (!(len is Int)) Context.error('Should eval to an integer.', lengthMeta.params[0].pos);
            return len;
        }
        switch field.kind {
            case FProp('default', 'null', _, e) | FVar(_, e):
                switch TypeTools.follow(src.type, true) {
                    case TAbstract(_.get().name == "Null" => true, _):
                        Context.error('Nullable types are not supported.', field.pos);
                    case _:
                }
                final compFieldType = switch Context.followWithAbstracts(src.type) {
                    case TAbstract(_.get().name => name, params):
                        if (typeName == null) typeName = switch name {
                            case 'Float': 'f64';
                            case 'Int': 'i32';
                            case 'Bool':
                                mod.valGet = e -> macro $e > 0;
                                mod.valSet = e -> macro if ($e) 1 else 0;
                                'ui8';
                            case _:
                                Context.error('Could not process component field type.', field.pos);
                        }
                        BitEcs(typeName);
                    case TInst(_.get().name == 'Array' => true, params):
                        switch params[0] {
                            case TAbstract(_.get().name => name, params):
                                if (typeName == null) typeName = switch name {
                                    case 'Float': 'f64';
                                    case 'Int': 'i32';
                                    case _: Context.error('Only Float and Int types are support for arrays.', field.pos);
                                }
                                BitEcsArray(typeName, getArrLength());
                            case _:
                                Mapped;
                        }
                    case TInst(_.get() => t, params)
                        if (t.pack.join('.') == 'js.lib' && bitEcsTypeToCT.exists(bt -> bt.names.contains(t.name))):
                        if (typeMeta != null) Context.warning('Metadata ignored.', typeMeta.pos);

                        BitEcsArray(t.name, getArrLength());
                    case _:
                        if (typeMeta != null) Context.warning('Mapped type. Metadata ignored.', typeMeta.pos);
                        Mapped;
                }
                if (compFieldType.match(BitEcs('eid' | 'entity'))
                    || (compFieldType.match(BitEcs('i32')) && src.type.getID() == 'bitecs.Entity')) {
                    mod.valGet = e -> macro cast $e;
                    mod.valSet = e -> macro cast $e;
                }
                final writable = !field.access.contains(AFinal) && !field.kind.match(FProp(_, 'null', _));
                addCompField(compFieldType, mod, writable, e, src);
            case FFun(f):
                if (field.name == 'new') customCtr(field, f);
                else funFields.push(field);
            case FProp('get', _) | FProp(_, 'set', _):
                Context.error('Custom getter/setter is not supported. Use an explicit function.', field.pos);
            case _: Context.error("Failed to process field.", field.pos);
        }
    }

    function addCompField(type:CompFieldType, mod:{valGet:Expr->Expr, valSet:Expr->Expr}, writable:Bool, expr:Expr, src:SourceField) {
        final field = src.field;
        var ct = src.ct;
        var storeDefField = null;
        final storeField = {
            name: field.name,
            pos: field.pos,
            kind: switch type {
                case BitEcs(typeName) | BitEcsArray(typeName, _):
                    var bitEcsType = bitEcsTypeToCT.find(t -> t.names.contains(typeName));
                    if (bitEcsType == null) haxe.macro.Context.error('Failed to determine bitECS type.', field.pos);
                    storeDefField = {
                        field: field.name,
                        expr: bitEcsType.expr.expr.at(field.pos)
                    };
                    var storeCt = bitEcsType.ct;
                    switch type {
                        case BitEcsArray(_, size):
                            storeCt = macro:Array<$storeCt>;
                            // Make type be a typed array, if the wanted type doesn't unify with it.
                            if (!ComplexTypeTools.toType(bitEcsType.ct).unifiesWith(src.type))
                                ct = bitEcsType.ct;
                            storeDefField.expr = macro [${storeDefField.expr}, untyped $v{size}];
                        case _:
                    }
                    FieldType.FVar(storeCt);
                case Mapped:
                    FieldType.FVar(macro:js.lib.Map<bitecs.Entity, $ct>);
            },
            doc: field.doc
        };

        var initExpr = null;
        if (expr != null) {
            if (!type.match(Mapped)) switch expr { // Check for null assignment.
                case macro null: Context.error('Null cannot be stored in bitECS store.', expr.pos);
                case _:
            }
            final fname = field.name;
            initExpr = macro this.$fname = $expr;
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
        var privateFields:Array<String> = [];
        for (field in compFields) {
            final fname = field.storeField.name;
            final prop = Member.prop(fname, field.ct, field.storeField.pos);
            prop.publish();
            wrapperFields.push(prop);
            var valExpr = macro v;
            if (field.mod.valSet != null) valExpr = field.mod.valSet(valExpr);
            var propExprs = switch field.type {
                case BitEcs(_) | BitEcsArray(_):
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
            if (field.type.match(BitEcsArray(_))) { // Only have setters for non-array fields.
                prop.kind = switch prop.kind {
                    case FProp(get, set, t, e): FProp(get, 'never', t, e);
                    case _: throw "unexpected";
                }
            } else {
                wrapperFields.push(setter);
            }
            if (!field.writable) {
                privateFields.push(prop.name);
                final privateName = '_' + prop.name;
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
                args: initExtraArgs,
                ret: voidType,
                expr: remap(initFieldExprs.concat(initExtraExpr).toBlock(typePos), privateFields)
            }),
            access: [APublic, AInline],
            doc: 'Sets the component values to their defaults.'
        });
        final selfCt = ComplexType.TPath(wrapperPath);
        var tthis = Member.method('tthis', false, ({ args: [], expr: macro return (cast this:$selfCt) }:Function));
        tthis.isBound = true;
        wrapperFields.push(tthis);

        for (f in funFields) wrapperFields.push(f);

        // Remap `this` and readonly fields.
        for (f in funFields) switch f.kind {
            case FFun(f): f.expr = remap(f.expr, privateFields);
            case _: throw "unexpected";
        }

        wrapper = {
            pack: wrapperPath.pack,
            name: wrapperPath.name,
            pos: typePos,
            kind: TDAbstract(TAnonymous([
                { name: 'ent', kind: FVar(entityType), pos: typePos },
                { name: 'store', kind: FVar(storeType), pos: typePos }
            ])),
            fields: wrapperFields.concat([
                {
                    name: 'new',
                    kind: FFun({
                        params: [{ name: 'E', constraints: [entityType] }],
                        args: [{ name: 'ent', type: macro:E }, { name: 'store', type: storeType }],
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

    BitEcs(typeName:String);
    BitEcsArray(typeName:String, size:Int);
    Mapped;

}

private var worldType = macro:bitecs.World;
private var entityType = macro:bitecs.Entity;
private var voidType = macro:Void;

private var bitEcsTypeToCT = [
    { names: ['Int8Array', 'i8', 'int8'], ct: macro:js.lib.Int8Array, expr: macro bitecs.Bitecs.Types.i8 },
    { names: ['Uint8Array', 'ui8', 'uint8'], ct: macro:js.lib.Uint8Array, expr: macro bitecs.Bitecs.Types.ui8 },
    { names: ['Uint8ClampedArray', 'ui8c'], ct: macro:js.lib.Uint8ClampedArray, expr: macro bitecs.Bitecs.Types.ui8c },
    { names: ['Int16Array', 'i16', 'int16'], ct: macro:js.lib.Int16Array, expr: macro bitecs.Bitecs.Types.i16 },
    { names: ['Uint16Array', 'ui16', 'uint16'], ct: macro:js.lib.Uint16Array, expr: macro bitecs.Bitecs.Types.ui16 },
    { names: ['Int32Array', 'i32', 'int32'], ct: macro:js.lib.Int32Array, expr: macro bitecs.Bitecs.Types.i32 },
    { names: ['Uint32Array', 'ui32', 'uint32'], ct: macro:js.lib.Uint32Array, expr: macro bitecs.Bitecs.Types.ui32 },
    { names: ['Float32Array', 'f32', 'float32'], ct: macro:js.lib.Float32Array, expr: macro bitecs.Bitecs.Types.f32 },
    { names: ['Float64Array', 'f64', 'float64'], ct: macro:js.lib.Float64Array, expr: macro bitecs.Bitecs.Types.f64 },
    { names: ['Uint32Array', 'eid', 'entity'], ct: macro:js.lib.Uint32Array, expr: macro bitecs.Bitecs.Types.eid },
];

private function remap(e:Expr, privateFields:Array<String>):Expr {
    function replace(e:Expr) {
        return switch e.expr {
            case EConst(CIdent(_ == 'this' => true)): macro @:pos(e.pos) tthis();
            case EField({ expr: EConst(CIdent(_ == 'this' => true)) }, field):
                if (privateFields.contains(field)) field = '_' + field;
                macro @:pos(e.pos) tthis().$field;
            case _: ExprTools.map(e, replace);
        }
    }
    return replace(e);
}

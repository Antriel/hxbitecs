package bitecs;

#if !macro
@:autoBuild(bitecs.World.build()) class World {

    public function new(?size:Int) {
        Bitecs.createWorld(this, size);
    }

}
#else
import haxe.macro.Context;
import haxe.macro.Expr;

using tink.MacroApi;

@:persistent var components:Map<String, {
    name:String,
    type:haxe.macro.Type
}> = [];

function build() {
    var fields = Context.getBuildFields();
    // Make sure all the components used in queries are typed, so `components` is filled.
    for (field in fields) {
        switch field.kind {
            case FVar(t, e): typeType(t.toType().sure());
            case FFun(f): if (field.name == 'new') f.expr.iter(typeAllTypes);
            case FProp(get, set, t, e): typeType(t.toType().sure());
        }
    }
    // Create stores for the components in this class.
    for (c in components) {
        fields.push({
            name: c.name.substr(0, 1).toLowerCase() + c.name.substr(1),
            // TODO proper types.
            kind: FVar(macro:Dynamic, macro Bitecs.defineComponent(${Component.getDefinition(c.type)})),
            pos: Context.currentPos(),
            access: [APublic, AFinal]
        });
    }
    return fields;
}

private function typeAllTypes(e:Expr) {
    switch e.expr {
        case ENew(t, params): typeType(TPath(t).toType().sure());
        case EVars(vars):
            for (v in vars) {
                if (v.type != null) typeType(v.type.toType().sure());
                else if (v.expr != null) typeAllTypes(v.expr);
            }
        case EFunction(kind, f): if (f.ret != null) typeType(f.ret.toType().sure());
        case ECast(e, t): typeType(t.toType().sure());
        case ECheckType(e, t): typeType(t.toType().sure());
        case EIs(e, t): typeType(t.toType().sure());
        case _: e.iter(typeAllTypes);
    }
}

private function typeType(t:haxe.macro.Type) {
    // Type the supplied type and its fields, so that Queries are done, and `components` filled.
    for (f in t.getFields().sure()) {
        f.type.reduce();
    }
}
#end

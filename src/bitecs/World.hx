package bitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import bitecs.Component.CompDef;

using tink.MacroApi;

@:persistent var components:Map<String, {
    name:String,
    type:haxe.macro.Type,
    ?def:CompDef
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
    for (c in components) {
        // Create stores for the components in this class.
        var def = Component.getDefinition(c.type);
        fields.push({
            name: c.name,
            kind: def.instanceVar,
            pos: Context.currentPos(),
            access: [APublic, AFinal]
        });
        c.def = def;
        Context.defineType(def.wrapper);
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

private function addComponentImpl(world:Expr, comp:Expr, eid:Expr) {
    var compData = null;
    try {
        final type = Context.getType(comp.toString());
        compData = components.get(type.getID());
        if (compData == null) Context.error('Component not registered, is it used in any query?', comp.pos);
    } catch (e) {
        Context.error('Could not find type: $e', comp.pos);
    }
    final cname = compData.name;
    final wrapperPath = compData.def.wrapperPath;
    var res = macro bitecs.Bitecs.addComponent($world, $world.$cname, $eid);
    res = res.concat(macro var wrapper = new $wrapperPath($eid, $world.$cname));
    res = res.concat(macro wrapper.init());
    res = res.concat(macro wrapper);
    return res;
}
#end

@:autoBuild(bitecs.World.build()) class World {

    #if !macro
    public function new(?size:Int) {
        Bitecs.createWorld(this, size);
    }
    #end

    public macro function addComponent(world, comp, eid) return addComponentImpl(world, comp, eid);

    // TODO add `w.get(Component, eid, ?check)`.

}

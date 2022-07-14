package bitecs;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import tink.macro.BuildCache;
import bitecs.Component.CompDef;

using tink.MacroApi;

@:persistent var components:TypeMap<{
    name:String,
    def:CompDef
}>;

function build() {
    components = new TypeMap(t -> switch t { // Don't follow typedefs, so we can alias components.
        case TLazy(f): f();
        case _: t;
    });
    final fields = Context.getBuildFields();
    var res = BuildCache.getTypeN('bitecs.World', (ctx:BuildContextN) -> {
        // Create stores for the components in this class.
        for (comp in ctx.types) switch comp {
            case TAnonymous(_.get().fields => anonFields):
                for (f in anonFields) registerCompType(fields, f.type, f.name);
            case _: registerCompType(fields, comp);
        }
        var name = ctx.name;
        var f = macro class $name { }

        f.fields = fields;
        f;

    });
    return TypeTools.toComplexType(res);
}

private function registerCompType(fields:Array<Field>, comp:Type, ?name:String):Void {
    if (!components.exists(comp)) {
        final def = Component.getDefinition(comp);
        Context.defineType(def.wrapper);
        if (name == null) name = switch TypeTools.toComplexType(comp) {
            case TPath(p): p.name.substr(0, 1).toLowerCase() + p.name.substr(1);
            case _: throw "unexpected";
        };
        components.set(comp, {
            name: name,
            def: def
        });
    }
    final c = components.get(comp);
    fields.push({
        name: c.name,
        kind: FVar(c.def.storeType, c.def.initExpr),
        pos: Context.currentPos(),
        access: [APublic, AFinal]
    });
    fields.push({
        name: 'add' + c.name.substr(0, 1).toUpperCase() + c.name.substr(1),
        pos: Context.currentPos(),
        kind: FFun({
            args: [{ name: 'eid', type: entityType }],
            expr: addComponentImpl(comp)
        }),
        access: [APublic, AInline]
    });
}

private function addComponentImpl(comp:Type) {
    var res = [];
    var compData = null;
    try {
        compData = components.get(comp);
        if (compData == null) Context.error('Component not registered, is it used in any query?', Context.currentPos());
    } catch (e) {
        Context.error('Could not find type: $e', Context.currentPos());
    }
    final cname = compData.name;
    final wrapperPath = compData.def.wrapperPath;
    res.push(macro bitecs.Bitecs.addComponent(this, this.$cname, eid));
    res.push(macro var $cname = new $wrapperPath(eid, this.$cname));
    res.push((macro $i{cname}).field('init').call());
    // Result value is just the wrapper.
    res.push(macro return $i{cname});
    return res.toBlock();
}

private var entityType = macro:bitecs.Entity;

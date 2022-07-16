package bitecs;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import tink.macro.BuildCache;
import bitecs.Component.ComponentDefinition;
import bitecs.Utils;

using tink.MacroApi;

@:persistent var components:TypeMap<{
    name:String,
    type:Type,
    def:ComponentDefinition
}> = new TypeMap(t -> switch t { // Don't follow typedefs, so we can alias components.
    case TLazy(f): f();
    case _: t;
});

function parseComponent(type:Type) return switch type {
    case TAnonymous(_.get().fields => anonFields):
        [for (f in anonFields) registerComponent(f.type, f.name)];
    case _: [registerComponent(type)];
}

private function registerComponent(comp:Type, ?name:String) {
    var exists = components.exists(comp);
    if (exists && name != null && components.get(comp).name != name) {
        Context.warning('Component ${comp.getID()} was already registered under a different name, replacing it.', Context.currentPos());
        exists = false;
    }
    if (!exists) {
        final def = Component.getDefinition(comp);
        Context.defineType(def.wrapper);
        if (name == null) name = switch TypeTools.toComplexType(comp) {
            case TPath(p): firstToLower(if (p.sub != null) p.sub else p.name);
            case _: throw "unexpected";
        };
        components.set(comp, {
            name: name,
            type: comp,
            def: def
        });
    }
    return components.get(comp);
}

function build() {
    final fields = Context.getBuildFields();
    var res = BuildCache.getTypeN('bitecs.World', (ctx:BuildContextN) -> {
        // Create stores for the components in this class.
        for (compType in ctx.types) {
            for (comp in parseComponent(compType)) addComponentField(fields, comp);
        }
        var name = ctx.name;
        var f = macro class $name { }

        f.fields = fields;
        f;

    });
    return TypeTools.toComplexType(res);
}

private function addComponentField(fields:Array<Field>, c):Void {
    fields.push({
        name: c.name,
        kind: FVar(c.def.storeType, c.def.initExpr),
        pos: Context.currentPos(),
        access: [APublic, AFinal]
    });
    fields.push({
        name: 'add' + firstToUpper(c.name),
        pos: Context.currentPos(),
        kind: FFun({
            args: [{ name: 'eid', type: entityType }],
            expr: addComponentImpl(c)
        }),
        access: [APublic, AInline]
    });
    fields.push({
        name: 'get' + firstToUpper(c.name),
        pos: Context.currentPos(),
        kind: FFun({
            args: [{ name: 'eid', type: entityType }],
            expr: getComponentImpl(c)
        }),
        access: [APublic, AInline]
    });
}

private function addComponentImpl(comp) {
    final cname = comp.name;
    final wrapperPath = comp.def.wrapperPath;
    return macro {
        bitecs.Bitecs.addComponent(this, this.$cname, eid);
        var $cname = new $wrapperPath(eid, this.$cname);
        $i{cname}.init();
        // Result value is just the wrapper.
        return $i{cname};
    }
}

private function getComponentImpl(comp) {
    final cname = comp.name;
    final wrapperPath = comp.def.wrapperPath;
    return macro return new $wrapperPath(eid, this.$cname);
}

private var entityType = macro:bitecs.Entity;

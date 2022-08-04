package bitecs;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import tink.macro.BuildCache;
import bitecs.Component.ComponentDefinition;
import bitecs.Utils;

using tink.MacroApi;

// Don't follow typedefs, so we can alias components.
@:persistent var components:TypeMap<ComponentData> = new TypeMap(t -> switch t {
    case TLazy(f): f();
    case _: t;
});

function parseComponent(type:Type) {
    switch type.reduce() {
        case TAbstract(_.get() => t, params):
            if (t.meta.has(':bitecs.comps')) { // Parse from generated type.
                var params = t.meta.extract(':bitecs.comps')[0].params;
                var result = [];
                for (p in params) {
                    try {
                        var name = p.toString();
                        var t = Context.getType(name);
                        if (!components.exists(t)) Context.error('Component "$name" not registered yet?', Context.currentPos());
                        result.push(components.get(t));
                    } catch (e) {
                        Context.error('Failed to resolve components.', Context.currentPos());
                    }
                }
                return result;
            }
        case _:
    }
    return switch type {
        case TAnonymous(_.get().fields => anonFields):
            [for (f in anonFields) registerComponent(f.type, f.name)];
        case _: [registerComponent(type)];
    }
}

private function registerComponent(comp:Type, ?name:String) {
    if (name == null) name = switch TypeTools.toComplexType(comp) {
        case TPath(p): firstToLower(if (p.sub != null) p.sub else p.name);
        case _: throw "unexpected";
    };
    var exists = components.exists(comp);
    if (exists && name != null && components.get(comp).name != name) {
        Context.warning('Component ${comp.getID()} was already registered under a different name, replacing it.', Context.currentPos());
        exists = false;
    }
    if (exists) try {
        Context.resolveType(TPath(components.get(comp).def.wrapperPath), Context.currentPos());
    } catch (e) {
        exists = false; // Type was invalidated.
    }
    if (!exists) {
        final def = Component.getDefinition(comp);
        for (hook in Plugin.componentHooks) hook(comp, def);
        Context.defineModule('bitecs.gen.${def.wrapperPath.name}', [def.wrapper], def.source.imports, def.source.usings);
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

        var structure = getWorldStructure(ctx.types);
        var name = ctx.name;
        var f = macro class $name implements bitecs.World.IWorld<$structure> { }

        f.meta.push({
            name: ':using',
            pos: Context.currentPos(),
            params: [macro bitecs.WorldExtensions]
        });
        f.fields = fields;
        f;

    });
    return TypeTools.toComplexType(res);
}

function buildWorldOf() {
    var res = BuildCache.getTypeN('bitecs.WorldOf', (ctx:BuildContextN) -> {
        var structure = getWorldStructure(ctx.types);
        var name = ctx.name;
        var iworld = macro:bitecs.World.IWorld<Dynamic>;
        var f = macro class $name<T:$iworld & $structure> {

            @:from public static inline function fromStructure(s:$structure) return cast s;

        };

        var tt = macro:T;
        f.kind = TDAbstract(tt, [], [tt, iworld, structure]);
        f.meta.push({ name: ':forward', pos: ctx.pos });
        f.meta.push({ name: ':transitive', pos: ctx.pos });
        f.meta.push({ name: ':using', params: [macro bitecs.WorldExtensions], pos: ctx.pos });

        // trace(new haxe.macro.Printer().printTypeDefinition(f));
        f;
    });
    return res.toComplex();
}

private function getWorldStructure(types:Array<Type>) {
    var fields:Array<Field> = [];
    for (compType in types) for (comp in parseComponent(compType)) {
        fields.push({
            name: comp.name,
            kind: FVar(comp.def.storeType),
            access: [APublic, AFinal],
            pos: comp.type.getPosition().sure()
        });
    }
    return ComplexType.TAnonymous(fields);
}

private function addComponentField(fields:Array<Field>, c):Void {
    fields.push({
        name: c.name,
        kind: FVar(c.def.storeType, c.def.initExpr),
        pos: Context.currentPos(),
        access: [APublic, AFinal]
    });
}

private var entityType = macro:bitecs.Entity;

typedef ComponentData = {

    name:String,
    type:Type,
    def:ComponentDefinition

};

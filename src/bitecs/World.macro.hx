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
                return parseFromMetaExpr(params);
            }
        case TAnonymous(t):
            var comps = t.get().fields.map(f -> f.meta.extract(':bitecs.comp')[0]);
            if (!Lambda.exists(comps, c -> c == null))
                return parseFromMetaExpr(comps.map(c -> c.params[0]));
        case _:
    }
    return switch type {
        case TAnonymous(_.get().fields => anonFields):
            [for (f in anonFields) registerComponent(f.type, f.name)];
        case _: [registerComponent(type)];
    }
}

private function parseFromMetaExpr(exprs:Array<Expr>) {
    var result = [];
    for (e in exprs) {
        try {
            var name = e.toString();
            var t = Context.getType(name);
            if (!components.exists(t))
                Context.error('Component "$name" not registered yet?', Context.currentPos());
            result.push(components.get(t));
        } catch (e) {
            Context.error('Failed to resolve components.', Context.currentPos());
        }
    }
    return result;
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
        var initCompsExpr = [];
        var comps = [for (compType in ctx.types) for (comp in parseComponent(compType)) comp];
        for (comp in comps) {
            addComponentField(fields, comp);
            var name = comp.name;
            initCompsExpr.push(macro this.$name = ${comp.def.initExpr});
        }

        var structure = getWorldStructure(ctx.types);
        var name = ctx.name;
        report(Context.getPosInfos(ctx.pos).file, comps);
        var f = macro class $name implements bitecs.World.IWorld<$structure> { }

        f.meta.push({
            name: ':using',
            pos: Context.currentPos(),
            params: [macro bitecs.WorldExtensions]
        });
        switch Lambda.find(fields, f -> f.name == 'new').kind {
            case FFun(f): f.expr = f.expr.concat(initCompsExpr.toBlock());
            case _: throw "unexpected";
        }
        f.fields = fields;
        // trace(new haxe.macro.Printer().printTypeDefinition(f));
        f;

    });
    return TypeTools.toComplexType(res);
}

function report(name:String, comps:Array<ComponentData>) {
    var type = Context.definedValue('bitecs.report');
    if (type == null) return;
    Sys.println('Component report for $name:');
    var reports = [for (c in comps) c.def.getReport()];
    var totalBytes = Lambda.fold(reports, (r, total) -> r.bytes + total, 0);
    var totalMapped = Lambda.fold(reports, (r, total) -> r.mapped + total, 0);
    Sys.println('  Mapped fields count: $totalMapped');
    Sys.println('  Total bytes for all TypedArray fields: $totalBytes');
    switch type {
        case '1' | 'simple': // Nothing else.
        case 'full':
            for (r in reports) {
                Sys.println('    ${r.name} - Mapped ${r.mapped} / Bytes ${r.bytes}');
            }
        case other: Context.warning('Unknown `bitecs.report` config of "$other".', Context.currentPos());
    }
}

@:persistent var worldOfCompTypes = new TypeMap<Array<Type>>();

function buildWorldOf() {
    var compTypes;
    var res = BuildCache.getTypeN('bitecs.WorldOf', (ctx:BuildContextN) -> {
        var structure = getWorldStructure(ctx.types);
        compTypes = ctx.types;
        var name = ctx.name;
        var iworld = macro :bitecs.World.IWorld<Dynamic>;
        var f = macro class $name<T:$iworld & $structure> {

            @:from public static inline function fromStructure(s:$structure) return cast s;

        };

        var tt = macro :T;
        f.kind = TDAbstract(tt, [], [], [tt, iworld, structure]);
        f.meta.push({ name: ':forward', pos: ctx.pos });
        f.meta.push({ name: ':transitive', pos: ctx.pos });
        f.meta.push({ name: ':using', params: [macro bitecs.WorldExtensions], pos: ctx.pos });

        // trace(new haxe.macro.Printer().printTypeDefinition(f));
        f;
    });
    if (compTypes != null) worldOfCompTypes.set(res, compTypes);
    return res;
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
        kind: FVar(c.def.storeType),
        pos: Context.currentPos(),
        access: [APublic, AFinal]
    });
}

private var entityType = macro :bitecs.Entity;

typedef ComponentData = {

    name:String,
    type:Type,
    def:ComponentDefinition

};

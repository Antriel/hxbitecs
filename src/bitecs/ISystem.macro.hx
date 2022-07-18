package bitecs;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;

using tink.MacroApi;

function build() {
    var fields = Context.getBuildFields();
    var queries = [];
    var newField = null;
    var worldType = null;
    var worldCt = null;

    for (field in fields) switch field.kind {
        case FVar(t, e) if (Lambda.exists(field.meta, meta -> meta.name == ":bitecs.query")):
            switch t {
                case TPath(p): queries.push({ name: field.name, tp: p });
                case _: Context.error("Expected a type path.", field.pos);
            }
        case FFun(f) if (field.name == 'new'): newField = field;
        case _:
    }

    for (itf in Context.getLocalClass().get().interfaces) if (itf.t.get().name == 'ISystem') {
        worldType = itf.params[0];
        worldCt = TypeTools.toComplexType(worldType);
        break;
    }
    if (newField == null) {
        newField = Member.method('new', { args: [], expr: macro { } });
        fields.push(newField);
    }

    fields.push({
        name: 'world',
        pos: Context.currentPos(),
        kind: FVar(worldCt),
        access: [AFinal]
    });

    switch newField.kind {
        case FFun(f):
            f.args.unshift({ name: 'world', type: worldCt });
            var appendedExpr = macro this.world = world;
            for (query in queries) {
                var tp = query.tp;
                var name = query.name;
                appendedExpr = appendedExpr.concat(macro $i{name} = new $tp(world));
            }
            f.expr = macro { $appendedExpr; ${f.expr} };
        case _: throw "unexpected";
    }

    return fields;
}

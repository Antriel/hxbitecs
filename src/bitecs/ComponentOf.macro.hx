package bitecs;

import haxe.macro.Context;
import haxe.macro.Expr;

using tink.MacroApi;

function build() {
    return switch Context.getLocalType() {
        case TInst(t, params):
            var comp = World.parseComponent(params[0]);
            ComplexType.TPath(comp[0].def.wrapperPath);
        case _: throw "unexpected";
    }
}

package bitecs;

import haxe.macro.Context;
import haxe.macro.Expr;
import tink.macro.BuildCache;

using tink.MacroApi;

function build() {
    return switch Context.getLocalType() {
        case TInst(t, params):
            var compTypes = Lambda.flatten([for (param in params) World.parseComponent(param)]).map(c -> c.type);
            BuildCache.getTypeN('bitecs.gen.EntityOf', compTypes, (ctx:BuildContextN) -> {
                final fields = ctx.types.map(t -> World.components.get(t)).map(c -> ({
                    name: c.name,
                    pos: ctx.pos,
                    kind: FieldType.FVar(ComplexType.TPath(c.def.wrapperPath)),
                }:Field));
                var td:TypeDefinition = {
                    pack: ['bitecs', 'gen'],
                    name: ctx.name,
                    pos: ctx.pos,
                    kind: TDStructure,
                    fields: fields
                }
                // trace(new haxe.macro.Printer().printTypeDefinition(td));
                return td;
            });
        case _: throw "unexpected";
    }
}

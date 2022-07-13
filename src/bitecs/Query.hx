package bitecs;

#if !macro
@:genericBuild(bitecs.Query.build()) class Query<Rest> { }

#else
import haxe.macro.Context;
import haxe.macro.TypeTools;
import tink.macro.BuildCache;

using tink.MacroApi;

function build() {
    return switch Context.getLocalType() {
        case TInst(t, params):
            for (param in params) {
                final id = param.getID();
                if (!World.components.exists(id))
                    World.components.set(id, {
                        name: switch TypeTools.toComplexType(param) {
                            case TPath(p): p.name.substr(0, 1).toLowerCase() + p.name.substr(1);
                            case _: throw "unexpected";
                        },
                        type: param
                    });
            }
            BuildCache.getTypeN('Query', params, (ctx:BuildContextN) -> {
                var name = ctx.name;
                // TODO build the actual query.
                return macro class $name {

                    public function new() { }

                };
            });
        case _: throw "unexpected";
    }
}
#end

typedef QueryType<W> = (world:W, ?clearDiff:Bool) -> Array<Entity>;

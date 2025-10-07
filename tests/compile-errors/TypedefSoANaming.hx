// EXPECTED_OUTPUT: "SoAWrapper_Vector2"

import hxbitecs.Hx;

// Typedef for SoA using SoA helper
typedef Vector2 = hxbitecs.SoA<{x:Float, y:Float}>;

@:publicFields class World {
    function new() {}
    // Must explicitly declare type to preserve typedef name
    var pos:Vector2 = new Vector2();
}

class TypedefSoANaming {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());
        var eid = bitecs.Bitecs.addEntity(world);
        bitecs.Bitecs.addComponent(world, eid, world.pos);

        var query = new hxbitecs.HxQuery<World, [pos]>(world);
        for (e in query) {
            // This should trigger a compiler warning showing the type
            // which should be SoAWrapper_macros_Vector2 (not including x/y field names)
            $type(e.pos);
        }
    }
}

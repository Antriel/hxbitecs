// EXPECTED_ERROR: "component parameter must be a single component store, not an array"

import hxbitecs.Hx;

@:publicFields class World {
    function new() {}
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };
}

class HxGetArrayParam {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());
        var eid = bitecs.Bitecs.addEntity(world);

        // Should fail: Hx.get() expects single component, not array
        var comp = Hx.get(eid, [world.pos, world.vel]);
    }
}

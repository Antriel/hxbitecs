// EXPECTED_ERROR: "does not exist in component"

import hxbitecs.Hx;

@:publicFields class World {
    function new() {}
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
}

class InitInvalidField {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());
        var eid = bitecs.Bitecs.addEntity(world);

        // Should fail: 'z' field doesn't exist in pos component
        Hx.addComponent(world, eid, world.pos, {x: 10, y: 20, z: 30});
    }
}

// EXPECTED_ERROR: "Initializer must be an object literal"

import hxbitecs.Hx;

@:publicFields class World {
    function new() {}
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
}

class InitNonObjectLiteral {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());
        var eid = bitecs.Bitecs.addEntity(world);

        var init = {x: 10.0, y: 20.0}; // Store in variable
        // Should fail: init must be object literal, not variable
        Hx.addComponent(world, eid, world.pos, init);
    }
}

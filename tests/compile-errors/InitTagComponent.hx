// EXPECTED_ERROR: "Tag components have no fields and cannot be initialized with values"

import hxbitecs.Hx;

@:publicFields class World {
    function new() {}
    var isPoisoned = {}; // Tag component
}

class InitTagComponent {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());
        var eid = bitecs.Bitecs.addEntity(world);

        // Should fail: tag components cannot be initialized with values
        Hx.addComponent(world, eid, world.isPoisoned, {value: 1});
    }
}

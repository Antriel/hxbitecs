// EXPECTED_ERROR: "Tag components have no data fields and cannot be accessed directly"

import hxbitecs.Hx;

@:publicFields class World {
    function new() {}
    var isPoisoned = {}; // Tag component
}

class GetTagComponent {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());
        var eid = bitecs.Bitecs.addEntity(world);
        bitecs.Bitecs.addComponent(world, eid, world.isPoisoned);

        // Should fail: tag components have no data fields to access
        var tag = Hx.get(eid, world.isPoisoned);
    }
}

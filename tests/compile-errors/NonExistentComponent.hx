// EXPECTED_ERROR: "Component field"

import hxbitecs.HxQuery;

@:publicFields class World {
    function new() {}
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
}

class NonExistentComponent {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());

        // Should fail: "velocity" component doesn't exist in World
        var query = new HxQuery<World, [pos, velocity]>(world);
    }
}

// EXPECTED_ERROR: "Unsupported query term"

import hxbitecs.Hx;

@:publicFields class World {
    function new() {}
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };
}

class InvalidQueryOperator {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());

        // Should fail: "Nott" is not a valid operator (typo for "Not")
        for (entity in Hx.query(world, [pos, Nott(vel)])) {
            trace(entity.pos.x);
        }
    }
}

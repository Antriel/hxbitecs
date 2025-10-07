// EXPECTED_ERROR: "terms parameter must be an array literal"

import hxbitecs.Hx;

@:publicFields class World {
    function new() {}
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
}

class HxQueryNonArrayTerms {
    static function main() {
        var world = Bitecs.createWorld(new World());

        var terms = [world.pos]; // Store in variable
        // Should fail: terms must be array literal
        for (entity in Hx.query(world, terms)) {
            trace(entity.pos.x);
        }
    }
}

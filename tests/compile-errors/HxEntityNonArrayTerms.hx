// EXPECTED_ERROR: "terms parameter must be an array literal"

import hxbitecs.Hx;

@:publicFields class World {
    function new() {}
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
}

class HxEntityNonArrayTerms {
    static function main() {
        var world = Bitecs.createWorld(new World());
        var eid = Bitecs.addEntity(world);

        var terms = [world.pos]; // Store in variable
        // Should fail: terms must be array literal
        var entity = Hx.entity(world, eid, terms);
    }
}

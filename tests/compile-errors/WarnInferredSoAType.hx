// EXPECTED_OUTPUT: "inferred type"
// EXPECTED_OUTPUT: "Use an explicit typedef"

import hxbitecs.Hx;

// Typedef for SoA using SoA helper
typedef Vector2 = hxbitecs.SoA<{x:Float, y:Float}>;

@:publicFields class World {
    function new() {}
    // Intentionally missing explicit type - should trigger warning
    var pos = new Vector2();
}

class WarnInferredSoAType {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());
        var eid = bitecs.Bitecs.addEntity(world);

        // This should trigger the warning when the query inspects world.pos
        var query = new hxbitecs.HxQuery<World, [pos]>(world);
    }
}

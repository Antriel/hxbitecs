// EXPECTED_ERROR: "HxEntity requires one or two type parameters"

import hxbitecs.HxEntity;

@:publicFields class World {
    function new() {}
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };
}

class HxEntityThreeParams {
    static function main() {
        // Should fail: HxEntity accepts only 1 or 2 type parameters
        var entity:HxEntity<World, [pos], [vel]> = null;
    }
}

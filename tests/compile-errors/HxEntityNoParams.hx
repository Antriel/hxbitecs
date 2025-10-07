// EXPECTED_ERROR: "Not enough type parameters for hxbitecs.HxEntity"

import hxbitecs.HxEntity;

class HxEntityNoParams {
    static function main() {
        // Should fail: HxEntity requires type parameters
        var entity:HxEntity = null;
    }
}

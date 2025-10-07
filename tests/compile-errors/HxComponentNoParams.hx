// EXPECTED_ERROR: "Not enough type parameters for hxbitecs.HxComponent"

import hxbitecs.HxComponent;

class HxComponentNoParams {
    static function main() {
        // Should fail: HxComponent requires type parameter
        var comp:HxComponent = null;
    }
}

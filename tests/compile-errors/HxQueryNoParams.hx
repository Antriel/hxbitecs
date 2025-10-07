// EXPECTED_ERROR: "Not enough type parameters for hxbitecs.HxQuery"

import hxbitecs.HxQuery;

class HxQueryNoParams {
    static function main() {
        // Should fail: HxQuery requires type parameters
        var query:HxQuery = null;
    }
}

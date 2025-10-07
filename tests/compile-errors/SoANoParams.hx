// EXPECTED_ERROR: "Not enough type parameters for hxbitecs.SoA"

import hxbitecs.SoA;

class SoANoParams {
    static function main() {
        // Should fail: SoA requires type parameter
        var soa:SoA = null;
    }
}

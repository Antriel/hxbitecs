// EXPECTED_ERROR: "SoA can only be used with anonymous structures"

import hxbitecs.SoA;

class SoANonStruct {
    static function main() {
        // Should fail: SoA requires anonymous structure type, not Int
        var comp:SoA<Int> = null;
    }
}

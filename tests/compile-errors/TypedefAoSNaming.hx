// EXPECTED_OUTPUT: "AoSWrapper_PlayerData"

import hxbitecs.Hx;

// Typedef for AoS with many fields
typedef PlayerData = Array<{
    var id:Int;
    var name:String;
    var score:Int;
    var level:Int;
    var health:Float;
    var mana:Float;
    var isActive:Bool;
}>;

@:publicFields class World {
    function new() {}
    var playerData:PlayerData = [];
}

class TypedefAoSNaming {
    static function main() {
        var world = bitecs.Bitecs.createWorld(new World());
        var eid = bitecs.Bitecs.addEntity(world);
        bitecs.Bitecs.addComponent(world, eid, world.playerData);

        var query = new hxbitecs.HxQuery<World, [playerData]>(world);
        for (e in query) {
            // This should trigger a compiler warning showing the type
            // which should be AoSWrapper_macros_PlayerData (not including field names)
            $type(e.playerData);
        }
    }
}

package bitecs;

@:genericBuild(bitecs.World.build()) class World<Rest> {

    var universe:bitecs.Bitecs.Universe;

    public function new(?capacity:Int) {
        universe = Bitecs.createUniverse(capacity);
        Bitecs.createWorld(universe, this);
    }

}

@:genericBuild(bitecs.World.buildWorldOf()) class WorldOf<Rest> { }

// Used for static extensions.
@:remove interface IWorld<Components> { }

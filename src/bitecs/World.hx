package bitecs;

@:genericBuild(bitecs.World.build()) class World<Rest> {

    public function new(?size:Int) {
        Bitecs.createWorld(this, size);
    }

}

@:genericBuild(bitecs.World.buildWorldOf()) class WorldOf<Rest> { }

// Used for static extensions.
@:remove interface IWorld<Components> { }

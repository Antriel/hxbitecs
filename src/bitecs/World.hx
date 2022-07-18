package bitecs;

@:genericBuild(bitecs.World.build()) class World<Rest> {

    public function new(?size:Int) {
        Bitecs.createWorld(this, size);
    }

}

// Used for static extensions.
@:remove interface IWorld { }

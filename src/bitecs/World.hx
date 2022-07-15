package bitecs;

// TODO Consider changing to simpler IWorld auto build macro?
@:genericBuild(bitecs.World.build()) class World<Rest> {

    public function new(?size:Int) {
        Bitecs.createWorld(this, size);
    }

}

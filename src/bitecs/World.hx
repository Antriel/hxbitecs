package bitecs;

@:genericBuild(bitecs.World.build()) class World<Rest> {

    public function new(?size:Int) {
        Bitecs.createWorld(this, size);
    }

    public function foo() {
        return macro "foo";
    }

    // TODO add `w.get(Component, eid, ?check)`.

}

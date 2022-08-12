package cases;

import bitecs.Query.QueryType;

class TestDirectUsage extends Test {

    public function testSimple() {
        var world = new World();
        var movement = new MovementSystem(world);
        var e = Bitecs.addEntity(world);
        Bitecs.addComponent(world, world.position, e);
        Bitecs.addComponent(world, world.velocity, e);
        world.position.x[e] = 0;
        world.velocity.x[e] = 1;
        Assert.equals(0, world.position.x[e]);
        movement.update(1);
        Assert.equals(1, world.position.x[e]);
    }

}

final Vec2Def = { x: Bitecs.Types.f64, y: Bitecs.Types.f64 };

private class World {

    public final velocity:{x:Array<Float>, y:Array<Float>};
    public final position:{x:Array<Float>, y:Array<Float>};

    public function new() {
        var universe = Bitecs.createUniverse();
        Bitecs.createWorld(universe, this);
        position = Bitecs.defineComponent(universe, Vec2Def);
        velocity = Bitecs.defineComponent(universe, Vec2Def);
    }

}

private class MovementSystem {

    final world:World;
    final query:QueryType<Dynamic>;

    public function new(w:World) {
        world = w;
        query = Bitecs.defineQuery([w.position, w.velocity]);
    }

    public function update(dt:Float) {
        for (eid in query(world)) {
            world.position.x[eid] += world.velocity.x[eid] * dt;
            world.position.y[eid] += world.velocity.y[eid] * dt;
        }
    }

}

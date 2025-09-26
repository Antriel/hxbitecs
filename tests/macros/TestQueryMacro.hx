package macros;

class TestQueryMacro extends Test {

    var world:MyQueryWorld;

    public function setup() {
        world = Bitecs.createWorld(new MyQueryWorld());

        for (i in 1...11) {
            final entity = Bitecs.addEntity(world);
            Bitecs.addComponent(world, entity, world.pos);
            world.pos.x[entity] = i * 10.0;
            world.pos.y[entity] = i * 5.0;

            if (i % 2 == 0) {
                Bitecs.addComponent(world, entity, world.vel);
                world.vel.x[entity] = i + 1.0;
                world.vel.y[entity] = (i + 1.0) * 2.0;
            }

            if (i % 3 == 0) {
                Bitecs.addComponent(world, entity, world.health);
                world.health[entity] = { hp: 100 + i * 10 };
            }

            if (i % 5 == 0) {
                Bitecs.addComponent(world, entity, world.isPoisoned);
            }
        }
    }

    public function teardown() {
        Bitecs.deleteWorld(world);
    }

    public function testSimpleSoA() {
        var posVel:hxbitecs.QueryMacro<MyQueryWorld, [pos, vel]>;
        posVel = new hxbitecs.QueryMacro<MyQueryWorld, [pos, vel]>(world);

        var entityCount = 0;
        for (e in posVel) {
            e.pos.x += e.vel.x;
            e.pos.y += e.vel.y;
            entityCount++;
        }

        Assert.equals(5, entityCount);

        for (e in posVel) {
            Assert.equals((e.eid * 10.0) + (e.eid + 1.0), e.pos.x);
            Assert.equals((e.eid * 5.0) + ((e.eid + 1.0) * 2.0), e.pos.y);
        }
    }

}

@:publicFields class MyQueryWorld {

    function new() { }

    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };
    var health = new Array<{hp:Int}>();
    var isPoisoned = {};

}

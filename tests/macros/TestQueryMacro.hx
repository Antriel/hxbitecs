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

    public function testOrOperator() {
        var posOrVel = new hxbitecs.QueryMacro<MyQueryWorld, [Or(pos, vel)]>(world);

        var entityCount = 0;
        for (e in posOrVel) {
            entityCount++;
        }

        // All entities have pos, even entities have vel, so should get all 10 entities
        Assert.equals(10, entityCount);
    }

    public function testNotOperator() {
        var posNotVel = new hxbitecs.QueryMacro<MyQueryWorld, [pos, Not(vel)]>(world);

        var entityCount = 0;
        var oddEntityIds = [];
        for (e in posNotVel) {
            oddEntityIds.push(e.eid);
            entityCount++;
        }

        // Odd entities don't have vel, so should get 5 entities (1, 3, 5, 7, 9)
        Assert.equals(5, entityCount);
        Assert.same([1, 3, 5, 7, 9], oddEntityIds);
    }

    public function testAndOperator() {
        var posAndVel = new hxbitecs.QueryMacro<MyQueryWorld, [And(pos, vel)]>(world);

        var entityCount = 0;
        for (e in posAndVel) {
            entityCount++;
        }

        // Even entities have both pos and vel, so should get 5 entities
        Assert.equals(5, entityCount);
    }

    public function testComplexQuery() {
        var complexQuery = new hxbitecs.QueryMacro<MyQueryWorld,
            [pos, Or(health, isPoisoned), Not(vel)]>(world);

        var entityCount = 0;
        var foundEntityIds = [];
        for (e in complexQuery) {
            foundEntityIds.push(e.eid);
            entityCount++;
        }

        // Need entities with:
        // - pos (all have it)
        // - health (entities 3, 6, 9) OR isPoisoned (entities 5, 10)
        // - NOT vel (odd entities: 1, 3, 5, 7, 9)
        // Intersection: entities 3, 5, 9
        Assert.equals(3, entityCount);
        Assert.same([3, 5, 9], foundEntityIds);
    }

    public function testAnyAlias() {
        var posAnyVel = new hxbitecs.QueryMacro<MyQueryWorld, [Any(pos, vel)]>(world);

        var entityCount = 0;
        for (e in posAnyVel) {
            entityCount++;
        }

        // Any(pos, vel) should be same as Or(pos, vel)
        Assert.equals(10, entityCount);
    }

    public function testNoneAlias() {
        var noneVelHealth = new hxbitecs.QueryMacro<MyQueryWorld, [pos, None(vel, health)]>(world);

        var entityCount = 0;
        var foundEntityIds = [];
        for (e in noneVelHealth) {
            foundEntityIds.push(e.eid);
            entityCount++;
        }

        // Need entities with pos and neither vel nor health
        // Entities without vel: 1, 3, 5, 7, 9
        // Entities without health: all except 3, 6, 9
        // Intersection: 1, 5, 7
        Assert.equals(3, entityCount);
        Assert.same([1, 5, 7], foundEntityIds);
    }

    public function testEntityAccessor() {
        // Test EntityAccessor with pos component
        var entityPos = new hxbitecs.EntityAccessorMacro<MyQueryWorld, [pos]>(world, 1);

        Assert.equals(1, entityPos.eid);
        Assert.equals(10.0, entityPos.pos.x);
        Assert.equals(5.0, entityPos.pos.y);

        // Test EntityAccessor with pos and vel components for even entity
        var entityPosVel:hxbitecs.EntityAccessorMacro<MyQueryWorld, [pos, vel]>;
        entityPosVel = new hxbitecs.EntityAccessorMacro<MyQueryWorld, [pos, vel]>(world, 2);

        Assert.equals(2, entityPosVel.eid);
        Assert.equals(20.0, entityPosVel.pos.x);
        Assert.equals(10.0, entityPosVel.pos.y);
        Assert.equals(3.0, entityPosVel.vel.x);
        Assert.equals(6.0, entityPosVel.vel.y);
    }

    public function testEntityAccessorModification() {
        // Test modifying components through EntityAccessor
        var entity = new hxbitecs.EntityAccessorMacro<MyQueryWorld, [pos, vel]>(world, 4);

        // Store original values
        var originalPosX = entity.pos.x; // Should be 40.0
        var originalVelX = entity.vel.x; // Should be 5.0

        Assert.equals(40.0, originalPosX);
        Assert.equals(5.0, originalVelX);

        // Modify the position using velocity
        entity.pos.x += entity.vel.x;
        entity.pos.y += entity.vel.y;

        // Verify changes
        Assert.equals(45.0, entity.pos.x);
        Assert.equals(30.0, entity.pos.y);
    }

    public function testEntityAccessorWithHealth() {
        // Test EntityAccessor with AoS component (health)
        var entityHealth = new hxbitecs.EntityAccessorMacro<MyQueryWorld, [health]>(world, 3);

        Assert.equals(3, entityHealth.eid);
        Assert.equals(130, entityHealth.health.hp);

        // Test modifying health
        entityHealth.health.hp = 150;
        Assert.equals(150, entityHealth.health.hp);
    }

    public function testEntityAccessorWithTag() {
        // Test EntityAccessor with tag component (isPoisoned)
        var entityPoisoned = new hxbitecs.EntityAccessorMacro<MyQueryWorld, [isPoisoned]>(world, 5);

        Assert.equals(5, entityPoisoned.eid);
        // Tag components don't have properties, just existence
    }

}

@:publicFields class MyQueryWorld {

    function new() { }

    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };
    var health = new Array<{hp:Int}>();
    var isPoisoned = {};

}

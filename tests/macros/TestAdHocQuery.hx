package macros;

class TestAdHocQuery extends Test {

    var world:AdHocTestWorld;

    public function setup() {
        world = Bitecs.createWorld(new AdHocTestWorld());

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

    public function testAdHocQueryBasic() {
        var entityCount = 0;

        for (e in hxbitecs.Hx.query(world, [pos, vel])) {
            entityCount++;
            e.pos.x += e.vel.x;
            e.pos.y += e.vel.y;
        }

        Assert.equals(5, entityCount);

        // Verify the modifications were applied
        for (e in hxbitecs.Hx.query(world, [pos, vel])) {
            var originalPosX = e.eid * 10.0;
            var originalPosY = e.eid * 5.0;
            var velX = e.eid + 1.0;
            var velY = (e.eid + 1.0) * 2.0;

            Assert.equals(originalPosX + velX, e.pos.x);
            Assert.equals(originalPosY + velY, e.pos.y);
        }
    }

    public function testAdHocQuerySimpleComponents() {
        // Test with simple SoA components
        var entityCount = 0;
        for (e in hxbitecs.Hx.query(world, [pos])) {
            entityCount++;
            Assert.notNull(e.pos);
            Assert.isTrue(e.pos.x > 0);
            Assert.isTrue(e.pos.y > 0);
        }
        Assert.equals(10, entityCount);
    }

    public function testAdHocQueryAoSComponents() {
        // Test with AoS component (health)
        var entityCount = 0;
        for (e in hxbitecs.Hx.query(world, [health])) {
            entityCount++;
            Assert.notNull(e.health);
            Assert.isTrue(e.health.hp >= 100);
        }
        Assert.equals(3, entityCount); // Entities 3, 6, 9
    }

    public function testAdHocQueryTagComponents() {
        // Test with tag component (isPoisoned)
        var entityCount = 0;
        var poisonedIds = [];
        for (e in hxbitecs.Hx.query(world, [isPoisoned])) {
            entityCount++;
            poisonedIds.push(e.eid);
        }
        Assert.equals(2, entityCount);
        Assert.same([5, 10], poisonedIds);
    }

    public function testAdHocQueryOrOperator() {
        var entityCount = 0;
        for (e in hxbitecs.Hx.query(world, [Or(pos, vel)])) {
            entityCount++;
        }
        // All entities have pos, even entities have vel, so should get all 10 entities
        Assert.equals(10, entityCount);
    }

    public function testAdHocQueryNotOperator() {
        var entityCount = 0;
        var oddEntityIds = [];
        for (e in hxbitecs.Hx.query(world, [pos, Not(vel)])) {
            oddEntityIds.push(e.eid);
            entityCount++;
        }
        // Odd entities don't have vel, so should get 5 entities (1, 3, 5, 7, 9)
        Assert.equals(5, entityCount);
        Assert.same([1, 3, 5, 7, 9], oddEntityIds);
    }

    public function testAdHocQueryAndOperator() {
        var entityCount = 0;
        for (e in hxbitecs.Hx.query(world, [And(pos, vel)])) {
            entityCount++;
        }
        // Even entities have both pos and vel, so should get 5 entities
        Assert.equals(5, entityCount);
    }

    public function testAdHocQueryComplexOperators() {
        var entityCount = 0;
        var foundEntityIds = [];
        for (e in hxbitecs.Hx.query(world, [pos, Or(health, isPoisoned), Not(vel)])) {
            foundEntityIds.push(e.eid);
            entityCount++;
            // Verify we can access pos (all should have it)
            Assert.isTrue(e.pos.x > 0);
            // Both health and isPoisoned should be in wrapper since they're in Or()
        }
        // Need entities with:
        // - pos (all have it)
        // - health (entities 3, 6, 9) OR isPoisoned (entities 5, 10)
        // - NOT vel (odd entities: 1, 3, 5, 7, 9)
        // Intersection: entities 3, 5, 9
        Assert.equals(3, entityCount);
        Assert.same([3, 5, 9], foundEntityIds);
    }

    public function testAdHocQueryAnyAlias() {
        var entityCount = 0;
        for (e in hxbitecs.Hx.query(world, [Any(pos, vel)])) {
            entityCount++;
        }
        // Any(pos, vel) should be same as Or(pos, vel)
        Assert.equals(10, entityCount);
    }

    public function testAdHocQueryNoneAlias() {
        var entityCount = 0;
        var foundEntityIds = [];
        for (e in hxbitecs.Hx.query(world, [pos, None(vel, health)])) {
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

    public function testAdHocQueryNoneWithComponentAccess() {
        var entityCount = 0;
        for (e in hxbitecs.Hx.query(world, [pos, None(vel), health])) {
            entityCount++;
            // Verify pos is accessible
            Assert.isTrue(e.pos.x > 0);
            // Verify health is accessible at correct index
            Assert.notNull(e.health);
            Assert.isTrue(e.health.hp >= 100);
        }
        // Only entities with pos AND health AND NOT vel: entities 3, 9
        Assert.equals(2, entityCount);
    }

    public function testAdHocQueryNestedStructure() {
        // Test ad-hoc query with multiple component types in one query
        var results = [];
        for (e in hxbitecs.Hx.query(world, [pos, vel, health])) {
            results.push({
                eid: e.eid,
                posX: e.pos.x,
                velX: e.vel.x,
                hp: e.health.hp
            });
        }
        // Only entity 6 has all three components (pos, vel, health)
        Assert.equals(1, results.length);
        Assert.equals(6, results[0].eid);
    }

}

@:publicFields class AdHocTestWorld {

    function new() { }

    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };
    var health = new Array<{hp:Int}>();
    var isPoisoned = {};

}

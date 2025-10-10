package macros;

import macros.data.MyQueryWorld;

// Typedef for testing query.on() method
typedef MovingQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, vel]>;
typedef ComplexQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, Or(vel, health)]>;
typedef TagQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, isPoisoned]>;
typedef HealthQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, health]>;
typedef PosNotVelQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, Not(vel)]>;
typedef PosNoneVelHealthQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, None(vel, health)]>;

class TestHxQueryOn extends Test {

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

    public function testBasicQueryOn() {
        // Basic query using MovingQuery.on(world)
        var entityCount = 0;
        for (e in MovingQuery.on(world)) {
            Assert.isTrue(e.pos.x > 0);
            Assert.isTrue(e.vel.x > 0);
            entityCount++;
        }

        // Should find 5 entities with both pos and vel (even entities: 2, 4, 6, 8, 10)
        Assert.equals(5, entityCount);
    }

    public function testQueryOnWithOperators() {
        // Query with operators: ComplexQuery has [pos, Or(vel, health)]
        var entityCount = 0;
        var foundEntityIds = [];
        for (e in ComplexQuery.on(world)) {
            foundEntityIds.push(e.eid);
            entityCount++;
        }

        // Entities with pos AND (vel OR health):
        // - Even entities have vel: 2, 4, 6, 8, 10
        // - Entities with health: 3, 6, 9
        // Union: 2, 3, 4, 6, 8, 9, 10
        Assert.equals(7, entityCount);
        Assert.same([2, 3, 4, 6, 8, 9, 10], foundEntityIds);
    }

    public function testQueryOnComponentAccess() {
        // Verify component access works correctly through query.on()
        var initialPosX = world.pos.x[2];
        var initialVelX = world.vel.x[2];

        for (e in MovingQuery.on(world)) {
            if (e.eid == 2) {
                e.pos.x += e.vel.x;
                e.pos.y += e.vel.y;
            }
        }

        // Verify position was updated
        Assert.equals(initialPosX + initialVelX, world.pos.x[2]);
    }

    public function testQueryOnMultipleInvocations() {
        // Verify multiple invocations work independently (no shared state)
        var count1 = 0;
        for (e in MovingQuery.on(world)) {
            count1++;
        }

        var count2 = 0;
        for (e in MovingQuery.on(world)) {
            count2++;
        }

        // Both should return same count
        Assert.equals(count1, count2);
        Assert.equals(5, count1);
    }

    public function testQueryOnVsNewQuery() {
        // Verify query.on() returns same results as new HxQuery()
        var persistentQuery = new MovingQuery(world);

        var onIds = [];
        for (e in MovingQuery.on(world)) {
            onIds.push(e.eid);
        }

        var newIds = [];
        for (e in persistentQuery) {
            newIds.push(e.eid);
        }

        Assert.same(onIds, newIds);
    }

    public function testQueryOnVsHxQuery() {
        // Verify query.on() returns same results as Hx.query()
        var onIds = [];
        for (e in MovingQuery.on(world)) {
            onIds.push(e.eid);
        }

        var hxQueryIds = [];
        for (e in hxbitecs.Hx.query(world, [pos, vel])) {
            hxQueryIds.push(e.eid);
        }

        Assert.same(onIds, hxQueryIds);
    }

    public function testQueryOnWithTagComponents() {
        // Test query.on() works with tag components
        var entityCount = 0;
        var foundEntityIds = [];
        for (e in TagQuery.on(world)) {
            foundEntityIds.push(e.eid);
            entityCount++;
        }

        // Entities with both pos and isPoisoned: 5, 10
        Assert.equals(2, entityCount);
        Assert.same([5, 10], foundEntityIds);
    }

    public function testQueryOnWithAoSComponents() {
        // Test query.on() works with AoS components (health is Array<{hp:Int}>)

        var entityCount = 0;
        for (e in HealthQuery.on(world)) {
            Assert.isTrue(e.health.hp >= 100);
            entityCount++;
        }

        // Entities with health: 3, 6, 9
        Assert.equals(3, entityCount);
    }

    public function testQueryOnWithEntityTypeAnnotation() {
        // Test that query.on() returns entities compatible with HxEntity type annotations
        inline function processMovingEntity(e:hxbitecs.HxEntity<MovingQuery>) {
            e.pos.x += 1.0;
        }

        for (e in MovingQuery.on(world)) {
            processMovingEntity(e); // Should be type-compatible
        }

        // Verify all moving entities had their x position incremented
        Assert.equals(21.0, world.pos.x[2]); // Was 20.0
        Assert.equals(41.0, world.pos.x[4]); // Was 40.0
    }

    public function testQueryOnReusableTypedefs() {
        // Demonstrate the main benefit: reusable query definitions

        inline function damageEnemies(dmg:Int) {
            for (e in HealthQuery.on(world)) {
                e.health.hp -= dmg;
            }
        }

        inline function healEnemies(heal:Int) {
            for (e in HealthQuery.on(world)) {
                e.health.hp += heal;
            }
        }

        damageEnemies(10);
        Assert.equals(120, world.health[3].hp); // Was 130, now 120

        healEnemies(5);
        Assert.equals(125, world.health[3].hp); // Was 120, now 125
    }

    public function testQueryOnWithNotOperator() {
        // Test Not operator with query.on()

        var entityCount = 0;
        var oddEntityIds = [];
        for (e in PosNotVelQuery.on(world)) {
            oddEntityIds.push(e.eid);
            entityCount++;
        }

        // Odd entities don't have vel: 1, 3, 5, 7, 9
        Assert.equals(5, entityCount);
        Assert.same([1, 3, 5, 7, 9], oddEntityIds);
    }

    public function testQueryOnWithNoneOperator() {
        // Test None operator with query.on()

        var entityCount = 0;
        var foundEntityIds = [];
        for (e in PosNoneVelHealthQuery.on(world, { commit: false })) {
            foundEntityIds.push(e.eid);
            entityCount++;
        }

        // Entities without vel AND without health
        // Without vel: 1, 3, 5, 7, 9
        // Without health: all except 3, 6, 9
        // Intersection: 1, 5, 7
        Assert.equals(3, entityCount);
        Assert.same([1, 5, 7], foundEntityIds);
    }

    public function testQueryOnPersistentStillWorks() {
        // Ensure persistent query pattern still works alongside query.on()
        var persistentQuery = new MovingQuery(world);

        // Use persistent query multiple times
        for (e in persistentQuery) {
            e.pos.x += 1.0;
        }

        for (e in persistentQuery) {
            e.pos.x += 1.0;
        }

        // Verify position was updated twice
        Assert.equals(22.0, world.pos.x[2]); // Was 20.0, now 22.0
    }

}

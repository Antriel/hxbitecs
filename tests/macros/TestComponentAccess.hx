package macros;

class TestComponentAccess extends Test {

    var world:ComponentAccessWorld;

    public function setup() {
        world = Bitecs.createWorld(new ComponentAccessWorld());

        // Strategic entity setup for comprehensive component access testing
        // Entity 1: pos, vel, health - tests basic SoA + AoS combination
        var e1 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e1, world.pos);
        Bitecs.addComponent(world, e1, world.vel);
        Bitecs.addComponent(world, e1, world.health);
        world.pos.x[e1] = 10.0;
        world.pos.y[e1] = 20.0;
        world.vel.x[e1] = 1.0;
        world.vel.y[e1] = 2.0;
        world.health[e1] = { hp: 100, maxHp: 150 };

        // Entity 2: pos, damage, isPoisoned - tests SoA Int + Tag
        var e2 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e2, world.pos);
        Bitecs.addComponent(world, e2, world.damage);
        Bitecs.addComponent(world, e2, world.isPoisoned);
        world.pos.x[e2] = 30.0;
        world.pos.y[e2] = 40.0;
        world.damage[e2] = 25;

        // Entity 3: pos, vel, shield, isInvulnerable - tests all types mixed
        var e3 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e3, world.pos);
        Bitecs.addComponent(world, e3, world.vel);
        Bitecs.addComponent(world, e3, world.shield);
        Bitecs.addComponent(world, e3, world.isInvulnerable);
        world.pos.x[e3] = 50.0;
        world.pos.y[e3] = 60.0;
        world.vel.x[e3] = 3.0;
        world.vel.y[e3] = 4.0;
        world.shield[e3] = { value: 75.5 };

        // Entity 4: pos, health, damage - no vel, for negative tests
        var e4 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e4, world.pos);
        Bitecs.addComponent(world, e4, world.health);
        Bitecs.addComponent(world, e4, world.damage);
        world.pos.x[e4] = 70.0;
        world.pos.y[e4] = 80.0;
        world.health[e4] = { hp: 80, maxHp: 100 };
        world.damage[e4] = 15;

        // Entity 5: vel, shield, isPoisoned - no pos, for edge cases
        var e5 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e5, world.vel);
        Bitecs.addComponent(world, e5, world.shield);
        Bitecs.addComponent(world, e5, world.isPoisoned);
        world.vel.x[e5] = 5.0;
        world.vel.y[e5] = 6.0;
        world.shield[e5] = { value: 50.0 };
    }

    public function teardown() {
        Bitecs.deleteWorld(world);
    }

    public function testComponentOrderingConsistency() {
        // Test that [pos, vel] and [vel, pos] access the same underlying data correctly
        var queryPosVel = new hxbitecs.QueryMacro<ComponentAccessWorld, [pos, vel]>(world);
        var queryVelPos = new hxbitecs.QueryMacro<ComponentAccessWorld, [vel, pos]>(world);

        var posVelEntities = [];
        var velPosEntities = [];

        for (e in queryPosVel) {
            posVelEntities.push({
                eid: e.eid,
                posX: e.pos.x,
                posY: e.pos.y,
                velX: e.vel.x,
                velY: e.vel.y
            });
        }

        for (e in queryVelPos) {
            velPosEntities.push({
                eid: e.eid,
                posX: e.pos.x,
                posY: e.pos.y,
                velX: e.vel.x,
                velY: e.vel.y
            });
        }

        // Should have same entities with same data regardless of component order
        Assert.equals(posVelEntities.length, velPosEntities.length);

        for (i in 0...posVelEntities.length) {
            var pv = posVelEntities[i];
            var vp = velPosEntities[i];
            Assert.equals(pv.eid, vp.eid);
            Assert.equals(pv.posX, vp.posX);
            Assert.equals(pv.posY, vp.posY);
            Assert.equals(pv.velX, vp.velX);
            Assert.equals(pv.velY, vp.velY);
        }
    }

    public function testCrossReferenceDataIntegrity() {
        // Modify data through EntityAccessor
        var accessor = new hxbitecs.EntityAccessorMacro<ComponentAccessWorld, [pos, health]>(world, 1);

        // Verify initial values
        Assert.equals(10.0, accessor.pos.x);
        Assert.equals(100, accessor.health.hp);

        // Modify through accessor
        accessor.pos.x = 999.0;
        accessor.pos.y = 888.0;
        accessor.health.hp = 77;

        // Verify changes through QueryMacro
        var query = new hxbitecs.QueryMacro<ComponentAccessWorld, [pos, health]>(world);
        var found = false;

        for (e in query) {
            if (e.eid == 1) {
                Assert.equals(999.0, e.pos.x);
                Assert.equals(888.0, e.pos.y);
                Assert.equals(77, e.health.hp);
                found = true;
            }
        }

        Assert.isTrue(found);

        // Modify through QueryMacro and verify through EntityAccessor
        for (e in query) {
            if (e.eid == 1) {
                e.pos.x = 555.0;
                e.health.maxHp = 200;
                break;
            }
        }

        Assert.equals(555.0, accessor.pos.x);
        Assert.equals(200, accessor.health.maxHp);
    }

    public function testComplexQueryComponentAccess() {
        // Test that complex queries properly access component data
        var complexQuery = new hxbitecs.QueryMacro<ComponentAccessWorld,
            [pos, Or(health, shield), Not(isPoisoned)]>(world);

        var foundEntities = [];

        for (e in complexQuery) {
            foundEntities.push(e.eid);

            // Verify pos component is always accessible and correct
            Assert.isTrue(e.pos.x > 0);
            Assert.isTrue(e.pos.y > 0);

            // Verify entity-specific data
            switch e.eid {
                case 1: // has pos, health, no isPoisoned
                    Assert.equals(10.0, e.pos.x); // From previous test
                    Assert.equals(20.0, e.pos.y);
                case 3: // has pos, shield, isInvulnerable (no isPoisoned)
                    Assert.equals(50.0, e.pos.x);
                    Assert.equals(60.0, e.pos.y);
                case 4: // has pos, health, no isPoisoned
                    Assert.equals(70.0, e.pos.x);
                    Assert.equals(80.0, e.pos.y);
            }
        }

        // Should find entities 1, 3, 4 (have pos + (health OR shield) + NOT isPoisoned)
        Assert.same([1, 3, 4], foundEntities);
    }

    public function testDifferentComponentTypeAccess() {
        // Test accessing different component patterns in same query
        var mixedQuery = new hxbitecs.QueryMacro<ComponentAccessWorld,
            [pos, damage, shield]>(world);

        var entityCount = 0;
        for (e in mixedQuery) {
            entityCount++;

            // This should only match entities with all three: pos (SoA Float), damage (SoA Int), shield (AoS)
            // No entities in our setup have all three, so should be empty
            Assert.fail("No entities should match [pos, damage, shield] combination");
        }

        Assert.equals(0, entityCount);

        // Test a combination that should work
        var workingQuery = new hxbitecs.QueryMacro<ComponentAccessWorld, [pos, damage]>(world);
        var workingCount = 0;

        for (e in workingQuery) {
            workingCount++;

            // Should be entities 2 and 4
            if (e.eid == 2) {
                Assert.equals(30.0, e.pos.x);
                Assert.equals(25, e.damage);
            } else if (e.eid == 4) {
                Assert.equals(70.0, e.pos.x);
                Assert.equals(15, e.damage);
            }
        }

        Assert.equals(2, workingCount);
    }

    public function testTagComponentAccess() {
        // Test that tag components work correctly in queries and accessors
        var tagQuery = new hxbitecs.QueryMacro<ComponentAccessWorld, [pos, isPoisoned]>(world);

        var taggedEntities = [];
        for (e in tagQuery) {
            taggedEntities.push(e.eid);

            // Verify pos data is correct for tagged entities
            switch e.eid {
                case 2:
                    Assert.equals(30.0, e.pos.x);
                    Assert.equals(40.0, e.pos.y);
                case 5:
                    // Entity 5 has vel and shield but no pos, shouldn't be here
                    Assert.fail("Entity 5 should not match [pos, isPoisoned]");
            }
        }

        // Should only find entity 2 (has both pos and isPoisoned)
        Assert.same([2], taggedEntities);

        // Test EntityAccessor with tag
        var tagAccessor = new hxbitecs.EntityAccessorMacro<ComponentAccessWorld, [isPoisoned]>(world, 2);
        Assert.equals(2, tagAccessor.eid);
    }

    public function testMultipleComponentIndexing() {
        // Test that when we have many components, indexing is correct
        var allComponentQuery = new hxbitecs.QueryMacro<ComponentAccessWorld,
            [pos, vel, health, damage, shield]>(world);

        var foundAny = false;
        for (e in allComponentQuery) {
            foundAny = true;
            // No entity has all five components, this should be empty
            Assert.fail("No entity should have all five components");
        }

        Assert.isFalse(foundAny);

        // Test a realistic multi-component scenario
        var tripleQuery = new hxbitecs.QueryMacro<ComponentAccessWorld, [pos, vel, health]>(world);

        for (e in tripleQuery) {
            // Only entity 1 should match
            Assert.equals(1, e.eid);
            Assert.equals(10.0, e.pos.x);
            Assert.equals(1.0, e.vel.x);
            Assert.equals(100, e.health.hp);
        }
    }

    public function testNestedOperatorComponentAccess() {
        // Test nested operators to ensure component indexing works with complex term parsing
        var nestedQuery = new hxbitecs.QueryMacro<ComponentAccessWorld,
            [pos, Or(health, shield), Not(isInvulnerable)]>(world);

        var foundEntities = [];
        for (e in nestedQuery) {
            foundEntities.push(e.eid);

            // Verify pos is accessible
            Assert.isTrue(e.pos.x > 0);

            // Should be entities that have pos + ((health OR shield) AND NOT isInvulnerable)
            switch e.eid {
                case 1: // has pos, health, no isInvulnerable
                    Assert.equals(10.0, e.pos.x);
                case 4: // has pos, health, no isInvulnerable
                    Assert.equals(70.0, e.pos.x);
                case 5: // has shield, isPoisoned, no pos - shouldn't match due to no pos
                    Assert.fail("Entity 5 shouldn't match due to missing pos");
            }
        }

        // Should find entities 1 and 4
        Assert.same([1, 4], foundEntities);
    }

    public function testSimpleArrayAssignmentSyntax() {
        // This test demonstrates the key improvement: entity.damage = value should work

        // Test with QueryMacro
        var query = new hxbitecs.QueryMacro<ComponentAccessWorld, [pos, damage]>(world);

        for (e in query) {
            if (e.eid == 2) {
                // The main improvement: direct assignment syntax works!
                e.damage = 999;
                Assert.equals(999, e.damage);

                // Also test that it doesn't interfere with other component types
                e.pos.x = 555.0;
                Assert.equals(555.0, e.pos.x);
            }
        }

        // Test with EntityAccessor
        var accessor = new hxbitecs.EntityAccessorMacro<ComponentAccessWorld, [damage]>(world, 4);

        // Direct assignment should work here too
        accessor.damage = 777;
        Assert.equals(777, accessor.damage);

        // Verify the changes are persistent and visible across different access patterns
        for (e in query) {
            if (e.eid == 2) {
                Assert.equals(999, e.damage); // From QueryMacro assignment
            } else if (e.eid == 4) {
                Assert.equals(777, e.damage); // From EntityAccessor assignment
            }
        }
    }

    public function testSimpleArrayWrapperBehavior() {
        // Test that SimpleArray components (like damage) work correctly
        var damageQuery = new hxbitecs.QueryMacro<ComponentAccessWorld, [damage]>(world);

        var foundEntities = [];
        var damageValues = [];

        for (e in damageQuery) {
            foundEntities.push(e.eid);
            damageValues.push(e.damage);
        }

        // Should find entities 2 and 4
        Assert.same([2, 4], foundEntities);
        Assert.same([25, 15], damageValues);

        // Test modification through SimpleArray properties (this is the main improvement!)
        for (e in damageQuery) {
            if (e.eid == 2) {
                // Test reading
                var originalDamage = e.damage;
                Assert.equals(25, originalDamage);

                // Test assignment - this should work now!
                e.damage = 100;
                Assert.equals(100, e.damage);
            }
        }

        // Test EntityAccessor with SimpleArray assignment
        var damageAccessor = new hxbitecs.EntityAccessorMacro<ComponentAccessWorld, [damage]>(world, 2);
        Assert.equals(100, damageAccessor.damage);

        // Test cross-reference integrity: modify via EntityAccessor, verify via QueryMacro
        damageAccessor.damage = 75;

        for (e in damageQuery) {
            if (e.eid == 2) {
                Assert.equals(75, e.damage); // Should see the change made via EntityAccessor
            }
        }

        // Test cross-reference integrity: modify via QueryMacro, verify via EntityAccessor
        for (e in damageQuery) {
            if (e.eid == 4) {
                e.damage = 50; // Change entity 4's damage
                break;
            }
        }

        var damageAccessor4 = new hxbitecs.EntityAccessorMacro<ComponentAccessWorld, [damage]>(world, 4);
        Assert.equals(50, damageAccessor4.damage); // Should see the change made via QueryMacro
    }

    public function testComponentDataConsistencyAcrossQueries() {
        // Verify that the same component accessed through different queries gives same data
        var query1 = new hxbitecs.QueryMacro<ComponentAccessWorld, [pos]>(world);
        var query2 = new hxbitecs.QueryMacro<ComponentAccessWorld, [pos, health]>(world);
        var query3 = new hxbitecs.QueryMacro<ComponentAccessWorld, [health, pos]>(world);

        var posDataFromQuery1 = new Map<Int, {x:Float, y:Float}>();
        var posDataFromQuery2 = new Map<Int, {x:Float, y:Float}>();
        var posDataFromQuery3 = new Map<Int, {x:Float, y:Float}>();

        for (e in query1) {
            posDataFromQuery1[e.eid] = { x: e.pos.x, y: e.pos.y };
        }

        for (e in query2) {
            posDataFromQuery2[e.eid] = { x: e.pos.x, y: e.pos.y };
        }

        for (e in query3) {
            posDataFromQuery3[e.eid] = { x: e.pos.x, y: e.pos.y };
        }

        // Verify all queries that include pos show the same pos data
        for (eid in posDataFromQuery2.keys()) {
            var data1 = posDataFromQuery1[eid];
            var data2 = posDataFromQuery2[eid];
            var data3 = posDataFromQuery3[eid];

            Assert.equals(data1.x, data2.x);
            Assert.equals(data1.y, data2.y);
            Assert.equals(data1.x, data3.x);
            Assert.equals(data1.y, data3.y);
        }
    }
}

@:publicFields class ComponentAccessWorld {

    function new() { }

    // SoA Float components
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };

    // AoS components
    var health = new Array<{hp:Int, maxHp:Int}>();
    var shield = new Array<{value:Float}>();

    // SoA Int component
    var damage = new Array<Int>();

    // Tag components
    var isPoisoned = {};
    var isInvulnerable = {};
}

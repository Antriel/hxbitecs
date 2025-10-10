package macros;

import macros.data.MyQueryWorld.*;
import macros.data.MyQueryWorld;

class TestHxQueryStaticEntity extends Test {

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

    public function testBasicStaticEntity() {
        // Basic usage using MovingQuery.entity(world, eid)
        var entity = MovingQuery.entity(world, 2);

        Assert.equals(2, entity.eid);
        Assert.equals(20.0, entity.pos.x);
        Assert.equals(10.0, entity.pos.y);
        Assert.equals(3.0, entity.vel.x);
        Assert.equals(6.0, entity.vel.y);
    }

    public function testStaticEntityComponentAccess() {
        // Verify component access works correctly through static entity method
        var entity = MovingQuery.entity(world, 4);

        var initialPosX = entity.pos.x;
        var initialVelX = entity.vel.x;

        entity.pos.x += entity.vel.x;
        entity.pos.y += entity.vel.y;

        // Verify position was updated in the world
        Assert.equals(initialPosX + initialVelX, world.pos.x[4]);
    }

    public function testStaticEntityMultipleInvocations() {
        // Verify multiple invocations work independently (no shared state)
        var entity1 = MovingQuery.entity(world, 2);
        var entity2 = MovingQuery.entity(world, 2);

        // Both should reference the same entity ID
        Assert.equals(entity1.eid, entity2.eid);
        Assert.equals(2, entity1.eid);

        // Changes through one should be visible through the other
        entity1.pos.x = 999.0;
        Assert.equals(999.0, entity2.pos.x);
        Assert.equals(999.0, world.pos.x[2]);
    }

    public function testStaticEntityVsHxEntity() {
        // Verify MyQuery.entity() returns same type as Hx.entity()
        var staticEntity = MovingQuery.entity(world, 2);
        var hxEntity = hxbitecs.Hx.entity(world, 2, [pos, vel]);

        // Both should have identical structure and behavior
        Assert.equals(staticEntity.eid, hxEntity.eid);
        Assert.equals(staticEntity.pos.x, hxEntity.pos.x);

        staticEntity.pos.x = 111.0;
        Assert.equals(111.0, hxEntity.pos.x);

        hxEntity.vel.y = 222.0;
        Assert.equals(222.0, staticEntity.vel.y);
    }

    public function testStaticEntityVsQueryGet() {
        // Verify MyQuery.entity() returns same type as query.get()
        var query = new MovingQuery(world);

        var staticEntity = MovingQuery.entity(world, 4);
        var queryEntity = query.get(4);

        // Both should reference the same entity and have identical behavior
        Assert.equals(staticEntity.eid, queryEntity.eid);
        Assert.equals(staticEntity.pos.x, queryEntity.pos.x);

        staticEntity.pos.x = 333.0;
        Assert.equals(333.0, queryEntity.pos.x);
        Assert.equals(333.0, world.pos.x[4]);
    }

    public function testStaticEntityWithTypeAnnotation() {
        // Test that static entity works with HxEntity type annotations
        var entity:hxbitecs.HxEntity<MovingQuery> = MovingQuery.entity(world, 6);

        Assert.equals(6, entity.eid);
        Assert.equals(60.0, entity.pos.x);
        Assert.equals(30.0, entity.pos.y);
    }

    public function testStaticEntityWithFunctionParameter() {
        // Test passing static entity to function with HxEntity parameter
        inline function processMovingEntity(e:hxbitecs.HxEntity<MovingQuery>) {
            e.pos.x += 1.0;
            e.pos.y += 1.0;
        }

        var entity = MovingQuery.entity(world, 8);
        var originalX = entity.pos.x;
        var originalY = entity.pos.y;

        processMovingEntity(entity);

        Assert.equals(originalX + 1.0, entity.pos.x);
        Assert.equals(originalY + 1.0, entity.pos.y);
    }

    public function testStaticEntityWithAoSComponents() {
        // Test static entity with AoS components (health is Array<{hp:Int}>)
        var entity = HealthQuery.entity(world, 3);

        Assert.equals(3, entity.eid);
        Assert.equals(130, entity.health.hp);

        // Modify through entity wrapper
        entity.health.hp = 200;
        Assert.equals(200, world.health[3].hp);
    }

    public function testStaticEntityWithTagComponents() {
        // Test static entity with tag components
        var entity = TagQuery.entity(world, 5);

        Assert.equals(5, entity.eid);
        Assert.equals(50.0, entity.pos.x);
        // Tag component isPoisoned is included in query but has no data fields
    }

    public function testStaticEntityWithOperators() {
        // Test static entity works with query operators
        var entity = ComplexQuery.entity(world, 3);

        Assert.equals(3, entity.eid);
        Assert.equals(30.0, entity.pos.x);
        Assert.equals(130, entity.health.hp);
    }

    public function testStaticEntityReusableTypedefs() {
        // Demonstrate the main benefit: reusable entity creation from typedef

        inline function damageEntity(eid:Int, dmg:Int) {
            var e = HealthQuery.entity(world, eid);
            e.health.hp -= dmg;
        }

        inline function healEntity(eid:Int, heal:Int) {
            var e = HealthQuery.entity(world, eid);
            e.health.hp += heal;
        }

        damageEntity(3, 10);
        Assert.equals(120, world.health[3].hp); // Was 130, now 120

        healEntity(3, 5);
        Assert.equals(125, world.health[3].hp); // Was 120, now 125
    }

    public function testStaticEntityStructuralSubtyping() {
        // Test that static entity supports structural subtyping

        // Function accepting entity with just [pos]
        inline function updatePosition(e:hxbitecs.HxEntity<MyQueryWorld, [pos]>) {
            e.pos.x = 777.0;
        }

        // Entity from MovingQuery (which has [pos, vel]) can be passed to function expecting only [pos]
        var entity = MovingQuery.entity(world, 10);
        updatePosition(entity); // Should work via structural subtyping

        Assert.equals(777.0, world.pos.x[10]);
    }

    public function testStaticEntityConsistencyWithQuery() {
        // Test that entities created from typedef match query iteration results
        var query = new MovingQuery(world);

        var queryEids = [];
        for (e in query) {
            queryEids.push(e.eid);
        }

        // Verify we can access the same entities using static entity method
        for (eid in queryEids) {
            var entity = MovingQuery.entity(world, eid);
            Assert.equals(eid, entity.eid);
            Assert.isTrue(entity.pos.x > 0);
            Assert.isTrue(entity.vel.x > 0);
        }
    }

    public function testStaticEntityWithNotOperator() {
        // Test Not operator with static entity
        var entity = PosNotVelQuery.entity(world, 1);

        Assert.equals(1, entity.eid);
        Assert.equals(10.0, entity.pos.x);
        // Entity 1 doesn't have vel (odd entity), so Not(vel) matches
    }

    public function testStaticEntityWithNoneOperator() {
        // Test None operator with static entity
        var entity = PosNoneVelHealthQuery.entity(world, 1);

        Assert.equals(1, entity.eid);
        Assert.equals(10.0, entity.pos.x);
        // Entity 1 doesn't have vel or health, so None(vel, health) matches
    }

    public function testStaticEntityComparison() {
        // Compare all three entity creation methods side-by-side
        var staticEntity = MovingQuery.entity(world, 2);
        var hxEntity = hxbitecs.Hx.entity(world, 2, [pos, vel]);
        var query = new MovingQuery(world);
        var queryEntity = query.get(2);

        // All three should be structurally identical
        Assert.equals(staticEntity.pos.x, hxEntity.pos.x);
        Assert.equals(staticEntity.pos.x, queryEntity.pos.x);
        Assert.equals(hxEntity.pos.x, queryEntity.pos.x);

        // Modifications through any should affect all
        staticEntity.pos.x = 555.0;
        Assert.equals(555.0, hxEntity.pos.x);
        Assert.equals(555.0, queryEntity.pos.x);
        Assert.equals(555.0, world.pos.x[2]);
    }

}

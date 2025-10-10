package macros;

import hxbitecs.Hx;
import macros.data.MyQueryWorld.*;
import macros.data.MyQueryWorld;

class TestQueryObservers extends Test {

    var world:MyQueryWorld;

    public function setup() {
        world = Bitecs.createWorld(new MyQueryWorld());
    }

    public function teardown() {
        Bitecs.deleteWorld(world);
    }

    public function testOnAddBasic() {
        // Track entities added to query
        var addedEntities:Array<Int> = [];

        // Set up observer before adding entities
        var unsub = MovingQuery.onAdd(world, (eid) -> {
            addedEntities.push(eid);
        });

        // Create entity with pos only - should not trigger
        var eid1 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, eid1, world.pos);

        // Add vel to complete the query - should trigger
        Bitecs.addComponent(world, eid1, world.vel);

        // Create entity with both pos and vel at once
        var eid2 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid2, world.pos, { x: 10, y: 20 });
        Hx.addComponent(world, eid2, world.vel, { x: 1, y: 2 });

        // Verify both entities triggered the observer
        Assert.equals(2, addedEntities.length);
        Assert.contains(eid1, addedEntities);
        Assert.contains(eid2, addedEntities);

        // Clean up
        unsub();
    }

    public function testOnRemoveBasic() {
        // Create entities with pos and vel
        var eid1 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid1, world.pos, { x: 10, y: 20 });
        Hx.addComponent(world, eid1, world.vel, { x: 1, y: 2 });

        var eid2 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid2, world.pos, { x: 30, y: 40 });
        Hx.addComponent(world, eid2, world.vel, { x: 3, y: 4 });

        // Track entities removed from query
        var removedEntities:Array<Int> = [];

        var unsub = MovingQuery.onRemove(world, (eid) -> {
            removedEntities.push(eid);
        });

        // Remove vel component - should trigger onRemove
        Bitecs.removeComponent(world, eid1, world.vel);

        // Remove entire entity - should also trigger onRemove
        Bitecs.removeEntity(world, eid2);

        // Verify both removals triggered the observer
        Assert.equals(2, removedEntities.length);
        Assert.contains(eid1, removedEntities);
        Assert.contains(eid2, removedEntities);

        // Clean up
        unsub();
    }

    public function testUnsubscribe() {
        var addedEntities:Array<Int> = [];

        var unsub = MovingQuery.onAdd(world, (eid) -> {
            addedEntities.push(eid);
        });

        // Create entity - should trigger
        var eid1 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid1, world.pos, { x: 10, y: 20 });
        Hx.addComponent(world, eid1, world.vel, { x: 1, y: 2 });

        Assert.equals(1, addedEntities.length);

        // Unsubscribe
        unsub();

        // Create another entity - should NOT trigger
        var eid2 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid2, world.pos, { x: 30, y: 40 });
        Hx.addComponent(world, eid2, world.vel, { x: 3, y: 4 });

        // Should still be 1, not 2
        Assert.equals(1, addedEntities.length);
    }

    public function testOnAddWithQueryOperators() {
        // Test observer with Not operator

        var addedEntities:Array<Int> = [];
        var unsub = PosNotVelQuery.onAdd(world, (eid) -> {
            if (addedEntities.indexOf(eid) == -1) addedEntities.push(eid);
        });
        var unsub2 = PosNotVelQuery.onRemove(world, (eid) -> {
            addedEntities.remove(eid);
        });

        // Create entity with just pos - should trigger
        var eid1 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid1, world.pos, { x: 10, y: 20 });

        Assert.equals(1, addedEntities.length);
        Assert.contains(eid1, addedEntities);

        // Create entity with pos and vel - should NOT trigger
        var eid2 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid2, world.pos, { x: 30, y: 40 });
        Hx.addComponent(world, eid2, world.vel, { x: 3, y: 4 });

        // Should still be 1
        Assert.equals(1, addedEntities.length);

        unsub();
        unsub2();
    }

    public function testOnAddWithOrOperator() {
        // Test observer with Or operator

        var addedEntities:Array<Int> = [];
        var unsub = PosOrVelQuery.onAdd(world, (eid) -> {
            if (addedEntities.indexOf(eid) == -1) addedEntities.push(eid);
        });

        // Create entity with just pos - should trigger
        var eid1 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid1, world.pos, { x: 10, y: 20 });

        // Create entity with just vel - should trigger
        var eid2 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid2, world.vel, { x: 1, y: 2 });

        // Create entity with both - should trigger
        var eid3 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid3, world.pos, { x: 30, y: 40 });
        Hx.addComponent(world, eid3, world.vel, { x: 3, y: 4 });

        Assert.equals(3, addedEntities.length);
        Assert.contains(eid1, addedEntities);
        Assert.contains(eid2, addedEntities);
        Assert.contains(eid3, addedEntities);

        unsub();
    }

    public function testMultipleObservers() {
        // Test multiple observers on the same query
        var observer1Calls:Array<Int> = [];
        var observer2Calls:Array<Int> = [];

        var unsub1 = MovingQuery.onAdd(world, (eid) -> {
            observer1Calls.push(eid);
        });

        var unsub2 = MovingQuery.onAdd(world, (eid) -> {
            observer2Calls.push(eid);
        });

        // Create entity
        var eid = Bitecs.addEntity(world);
        Hx.addComponent(world, eid, world.pos, { x: 10, y: 20 });
        Hx.addComponent(world, eid, world.vel, { x: 1, y: 2 });

        // Both observers should be called
        Assert.equals(1, observer1Calls.length);
        Assert.equals(1, observer2Calls.length);
        Assert.equals(eid, observer1Calls[0]);
        Assert.equals(eid, observer2Calls[0]);

        unsub1();
        unsub2();
    }

    public function testOnAddOnRemoveTogether() {
        // Test both onAdd and onRemove working together
        var addedEntities:Array<Int> = [];
        var removedEntities:Array<Int> = [];

        var unsubAdd = MovingQuery.onAdd(world, (eid) -> {
            addedEntities.push(eid);
        });

        var unsubRemove = MovingQuery.onRemove(world, (eid) -> {
            removedEntities.push(eid);
        });

        // Create entity - should trigger onAdd
        var eid = Bitecs.addEntity(world);
        Hx.addComponent(world, eid, world.pos, { x: 10, y: 20 });
        Hx.addComponent(world, eid, world.vel, { x: 1, y: 2 });

        Assert.equals(1, addedEntities.length);
        Assert.equals(0, removedEntities.length);

        // Remove entity - should trigger onRemove
        Bitecs.removeEntity(world, eid);

        Assert.equals(1, addedEntities.length);
        Assert.equals(1, removedEntities.length);
        Assert.equals(eid, removedEntities[0]);

        unsubAdd();
        unsubRemove();
    }

    public function testObserverWithComplexNotQuery() {
        // Test observer with complex query including multiple operators

        var addedEntities:Array<Int> = [];
        var unsub = ComplexNotQuery.onAdd(world, (eid) -> {
            if(!addedEntities.contains(eid)) addedEntities.push(eid);
        });
        var unsub2 = ComplexNotQuery.onRemove(world, (eid) -> {
            addedEntities.remove(eid);
        });

        // Entity with pos, health, no vel - should trigger
        var eid1 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid1, world.pos, { x: 10, y: 20 });
        Bitecs.addComponent(world, eid1, world.health);
        world.health[eid1] = { hp: 100 };

        // Entity with pos, isPoisoned, no vel - should trigger
        var eid2 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid2, world.pos, { x: 30, y: 40 });
        Bitecs.addComponent(world, eid2, world.isPoisoned);

        // Entity with pos, health, vel - should NOT trigger (has vel)
        var eid3 = Bitecs.addEntity(world);
        Hx.addComponent(world, eid3, world.pos, { x: 50, y: 60 });
        Bitecs.addComponent(world, eid3, world.health);
        world.health[eid3] = { hp: 100 };
        Hx.addComponent(world, eid3, world.vel, { x: 1, y: 2 });

        Assert.equals(2, addedEntities.length);
        Assert.contains(eid1, addedEntities);
        Assert.contains(eid2, addedEntities);
        Assert.isFalse(addedEntities.contains(eid3));

        unsub();
    }

}

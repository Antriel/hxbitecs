package externs;

class TestSimple extends Test {

    public function testWorldEntity() {
        final world = Bitecs.createWorld();
        final entity = Bitecs.addEntity(world);
        Assert.isTrue(Bitecs.entityExists(world, entity));
        Bitecs.removeEntity(world, entity);
        Assert.isFalse(Bitecs.entityExists(world, entity));
    }

    public function testComponent() {
        final world = Bitecs.createWorld();
        final Position = { x: [], y: [] };
        Bitecs.registerComponent(world, Position); // Optional.
        final entity = Bitecs.addEntity(world);
        Assert.isFalse(Bitecs.hasComponent(world, entity, Position));
        Bitecs.addComponent(world, entity, Position);
        Assert.isTrue(Bitecs.hasComponent(world, entity, Position));
        Position.x[entity] = 5;
        Position.y[entity] = 15; // Nothing to test here...
    }

    public function testComponentGetSet() {
        final world = Bitecs.createWorld();
        final Position = { x: [], y: [] };
        final entity = Bitecs.addEntity(world);

        Bitecs.observe(world, Bitecs.onSet(Position), function(eid, params):Void {
            Position.x[eid] = params.x;
            Position.y[eid] = params.y;
        });
        Bitecs.addComponent(world, entity, Bitecs.set(Position, { x: 1, y: 2 }));
        Assert.isTrue(Bitecs.hasComponent(world, entity, Position));
        Assert.equals(1, Position.x[entity]);
        Assert.equals(2, Position.y[entity]);

        final entity2 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, entity2, Position);
        Assert.isTrue(Bitecs.hasComponent(world, entity2, Position));
        Bitecs.setComponent(world, entity2, Position, { x: 10, y: 20 });
        Bitecs.observe(world, Bitecs.onGet(Position), (eid) -> {
            x: Position.x[eid],
            y: Position.y[eid],
        });
        final pos = Bitecs.getComponent(world, entity, Position);
        final pos2 = Bitecs.getComponent(world, entity2, Position);
        Assert.equals(pos.x, 1);
        Assert.equals(pos.y, 2);
        Assert.equals(pos2.x, 10);
        Assert.equals(pos2.y, 20);
    }

}

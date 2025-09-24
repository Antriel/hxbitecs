package externs;

class TestQueries extends Test {

    public function testQuerySimple() {
        final world = Bitecs.createWorld();
        final Position = { x: [], y: [] };
        final Velocity = { x: [], y: [] };
        final entity1 = Bitecs.addEntity(world);
        final entity2 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, entity1, Position);
        Bitecs.addComponent(world, entity1, Velocity);
        Bitecs.addComponent(world, entity2, Position);

        var result = Bitecs.query(world, [Position, Velocity]);
        Assert.same([entity1], result);
        result = Bitecs.query(world, [Position]);
        Assert.same([entity1, entity2], result);

        Bitecs.removeComponent(world, entity1, Velocity);

        result = Bitecs.query(world, [Position, Velocity]);
        Assert.equals(0, result.asType1.length);
    }

    public function testQueryModifiers() {
        final world = Bitecs.createWorld();
        final Position = { x: [], y: [] };
        final Velocity = { x: [], y: [] };
        final Health = { value: [] };

        final entity1 = Bitecs.addEntity(world);
        final entity2 = Bitecs.addEntity(world);
        final entity3 = Bitecs.addEntity(world);

        Bitecs.addComponent(world, entity1, Position);
        Bitecs.addComponent(world, entity1, Velocity);

        Bitecs.addComponent(world, entity2, Position);
        Bitecs.addComponent(world, entity2, Health);

        Bitecs.addComponent(world, entity3, Position);
        Bitecs.addComponent(world, entity3, Velocity);
        Bitecs.addComponent(world, entity3, Health);

        // Query for entities with Position and Velocity
        var result = Bitecs.query(world, [Bitecs.All(Position, Velocity)]);
        Assert.same([entity1, entity3], result);

        // Query for entities with Position and Health
        result = Bitecs.query(world, [Bitecs.All(Position, Health)]);
        Assert.same([entity2, entity3], result);

        // Query for entities with Position and either Velocity or Health
        result = Bitecs.query(world, [Position, Bitecs.Or(Velocity, Health)]);
        Assert.same([entity1, entity2, entity3], result);

        // Query for entities with Position but not Velocity
        result = Bitecs.query(world, [Position, Bitecs.Not(Velocity)]);
        Assert.same([entity2], result);

        // Query for entities with Position and any of Velocity or Health
        result = Bitecs.query(world, [Position, Bitecs.Any(Velocity, Health)]);
        Assert.same([entity1, entity2, entity3], result);

        // Query for entities with Position but none of Velocity or Health
        result = Bitecs.query(world, [Position, Bitecs.None(Velocity, Health)]);
        Assert.same([], result);
    }

}

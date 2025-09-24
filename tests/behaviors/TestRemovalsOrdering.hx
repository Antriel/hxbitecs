package behaviors;

class TestRemovalsOrdering extends Test {

    // The goal of this test is to ensure that removals are processed in forward iteration,
    // so that iteration order of queries is stable. Otherwise changes in when removals
    // are committed could change the order of entities in further query results.
    // I.e. we are checking that remove, remove, commit, keeps the same final order
    // remove, commit, remove, commit.
    public function testRemovalsOrdering() {
        final world = Bitecs.createWorld();
        final Tag = {};

        for (_ in 0...6) {
            final entity = Bitecs.addEntity(world);
            Bitecs.addComponent(world, entity, Tag);
        }
        var result = Bitecs.query(world, [Tag]);
        Assert.same([1, 2, 3, 4, 5, 6], result);

        // Remove 2 and 4, then iterate (commit).
        Bitecs.removeComponent(world, 2, Tag);
        Bitecs.removeComponent(world, 4, Tag);
        final result1 = Bitecs.query(world, [Tag]);

        Bitecs.resetWorld(world);
        for (_ in 0...6) {
            final entity = Bitecs.addEntity(world);
            Bitecs.addComponent(world, entity, Tag);
        }
        result = Bitecs.query(world, [Tag]);
        Assert.same([1, 2, 3, 4, 5, 6], result);
        // Remove 2, iterate, then remove 4.
        Bitecs.removeComponent(world, 2, Tag);
        result = Bitecs.query(world, [Tag]);
        Bitecs.removeComponent(world, 4, Tag);
        final result2 = Bitecs.query(world, [Tag]);
        Assert.same(result1, result2);
    }

}

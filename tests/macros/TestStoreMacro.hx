package macros;

class TestStoreMacro extends Test {

    public function testStoreMacro() {
        final world = Bitecs.createWorld({
            pos: new hxbitecs.SoA<Vec2>(),
            health: new hxbitecs.SoA<{hp:Int}>(),
            vel: new Array<{x:Float, y:Float}>(),
            damage: new Array<Int>(),
            speed: new js.lib.Float32Array(1000),
        });
        final entity1 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, entity1, world.pos);
        Assert.isTrue(Bitecs.hasComponent(world, entity1, world.pos));
        final ents = Bitecs.query(world, [world.pos]);
        Assert.equals(1, ents.asType1.length);
        Assert.equals(entity1, ents.asType1[0]);
        world.pos.x[entity1] = 10;
        world.vel[entity1] = { x: 10, y: 10 };
        world.health.hp[entity1] = 100;

        // Test simple array components
        Bitecs.addComponent(world, entity1, world.damage);
        world.damage[entity1] = 50;
        Assert.equals(50, world.damage[entity1]);

        Bitecs.addComponent(world, entity1, world.speed);
        world.speed[entity1] = 1.5;
        Assert.equals(1.5, world.speed[entity1]);

        // Test querying with simple array components
        final damageEnts = Bitecs.query(world, [world.damage]);
        Assert.equals(1, damageEnts.asType1.length);
        Assert.equals(entity1, damageEnts.asType1[0]);
    }

}

private typedef Vec2 = {

    var x:Float;
    var y:Float;

}

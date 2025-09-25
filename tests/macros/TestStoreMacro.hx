package macros;

class TestStoreMacro extends Test {

    public function testStoreMacro() {
        final world = Bitecs.createWorld({
            pos: new hxbitecs.SoA<Vec2>(),
            health: new hxbitecs.SoA<{hp:Int}>(),
            vel: new Array<{x:Float, y:Float}>(),
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
    }

}

private typedef Vec2 = {

    var x:Float;
    var y:Float;

}

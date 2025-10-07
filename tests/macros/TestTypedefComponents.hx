package macros;

class TestTypedefComponents extends Test {

    var world:TypedefComponentWorld;

    public function setup() {
        world = Bitecs.createWorld(new TypedefComponentWorld());

        // Entity 1: has position typedef (simple array)
        var e1 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e1, world.posSimple);
        world.posSimple[e1] = 10.0;

        // Entity 2: has position SoA typedef
        var e2 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e2, world.posSoA);
        world.posSoA.x[e2] = 20.0;
        world.posSoA.y[e2] = 30.0;

        // Entity 3: has velocity AoS typedef
        var e3 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e3, world.velAoS);
        world.velAoS[e3] = { x: 1.0, y: 2.0 };

        // Entity 4: has abstract position (SoA)
        var e4 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e4, world.posAbstract);
        world.posAbstract.x[e4] = 40.0;
        world.posAbstract.y[e4] = 50.0;
        // Entity 5: has abstract over typedef SoA
        var e5 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e5, world.posAbstractOverTypedef);
        world.posAbstractOverTypedef.x[e5] = 60.0;
        world.posAbstractOverTypedef.y[e5] = 70.0;

        // Entity 6: has abstract over typedef AoS
        var e6 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e6, world.velAbstractOverTypedef);
        world.velAbstractOverTypedef[e6] = { x: 3.0, y: 4.0 };

        // Entity 7: has abstract over typedef simple array
        var e7 = Bitecs.addEntity(world);
        Bitecs.addComponent(world, e7, world.posAbstractOverSimple);
        world.posAbstractOverSimple[e7] = 80.0;
    }

    public function teardown() {
        Bitecs.deleteWorld(world);
    }

    public function testTypedefSimpleArray() {
        // Test typedef for simple array component
        var query = new hxbitecs.HxQuery<TypedefComponentWorld, [posSimple]>(world);

        var found = false;
        for (e in query) {
            Assert.equals(1, e.eid);
            Assert.equals(10.0, e.posSimple);
            found = true;
        }

        Assert.isTrue(found);

        // Test modification
        for (e in query) {
            e.posSimple = 99.0;
        }

        Assert.equals(99.0, world.posSimple[1]);
    }

    public function testTypedefSoA() {
        // Test typedef for SoA component
        var query = new hxbitecs.HxQuery<TypedefComponentWorld, [posSoA]>(world);

        var found = false;
        for (e in query) {
            Assert.equals(2, e.eid);
            Assert.equals(20.0, e.posSoA.x);
            Assert.equals(30.0, e.posSoA.y);
            found = true;
        }

        Assert.isTrue(found);

        // Test modification
        for (e in query) {
            e.posSoA.x = 100.0;
            e.posSoA.y = 200.0;
        }

        Assert.equals(100.0, world.posSoA.x[2]);
        Assert.equals(200.0, world.posSoA.y[2]);
    }

    public function testTypedefAoS() {
        // Test typedef for AoS component
        var query = new hxbitecs.HxQuery<TypedefComponentWorld, [velAoS]>(world);

        var found = false;
        for (e in query) {
            Assert.equals(3, e.eid);
            Assert.equals(1.0, e.velAoS.x);
            Assert.equals(2.0, e.velAoS.y);
            found = true;
        }

        Assert.isTrue(found);

        // Test modification
        for (e in query) {
            e.velAoS.x = 5.0;
            e.velAoS.y = 6.0;
        }

        Assert.equals(5.0, world.velAoS[3].x);
        Assert.equals(6.0, world.velAoS[3].y);
    }

    public function testAbstractSoA() {
        // Test abstract for SoA component
        var query = new hxbitecs.HxQuery<TypedefComponentWorld, [posAbstract]>(world);

        var found = false;
        for (e in query) {
            Assert.equals(4, e.eid);
            Assert.equals(40.0, e.posAbstract.x);
            Assert.equals(50.0, e.posAbstract.y);
            found = true;
        }

        Assert.isTrue(found);

        // Test modification
        for (e in query) {
            e.posAbstract.x = 300.0;
            e.posAbstract.y = 400.0;
        }

        Assert.equals(300.0, world.posAbstract.x[4]);
        Assert.equals(400.0, world.posAbstract.y[4]);
    }

    public function testHxGetWithTypedef() {
        // Test Hx.get() with typedef SoA component
        var pos = hxbitecs.Hx.get(2, world.posSoA);
        Assert.equals(20.0, pos.x);
        Assert.equals(30.0, pos.y);

        pos.x = 111.0;
        pos.y = 222.0;

        // Verify changes
        var query = new hxbitecs.HxQuery<TypedefComponentWorld, [posSoA]>(world);
        for (e in query) {
            Assert.equals(111.0, e.posSoA.x);
            Assert.equals(222.0, e.posSoA.y);
        }
    }

    public function testHxEntityWithTypedef() {
        // Test Hx.entity with typedef components
        var accessor = hxbitecs.Hx.entity(world, 2, [posSoA, velAoS]);

        // Should only have posSoA (entity 2 doesn't have velAoS)
        Assert.equals(20.0, accessor.posSoA.x);
        Assert.equals(30.0, accessor.posSoA.y);

        accessor.posSoA.x = 500.0;
        Assert.equals(500.0, world.posSoA.x[2]);
    }

    public function testAbstractOverTypedefSoA() {
        // Test abstract wrapping typedef SoA
        var query = new hxbitecs.HxQuery<TypedefComponentWorld, [posAbstractOverTypedef]>(world);

        var found = false;
        for (e in query) {
            Assert.equals(5, e.eid);
            Assert.equals(60.0, e.posAbstractOverTypedef.x);
            Assert.equals(70.0, e.posAbstractOverTypedef.y);
            found = true;
        }

        Assert.isTrue(found);

        // Test modification
        for (e in query) {
            e.posAbstractOverTypedef.x = 150.0;
            e.posAbstractOverTypedef.y = 250.0;
        }

        Assert.equals(150.0, world.posAbstractOverTypedef.x[5]);
        Assert.equals(250.0, world.posAbstractOverTypedef.y[5]);
    }

    public function testAbstractOverTypedefAoS() {
        // Test abstract wrapping typedef AoS
        var query = new hxbitecs.HxQuery<TypedefComponentWorld, [velAbstractOverTypedef]>(world);

        var found = false;
        for (e in query) {
            Assert.equals(6, e.eid);
            Assert.equals(3.0, e.velAbstractOverTypedef.x);
            Assert.equals(4.0, e.velAbstractOverTypedef.y);
            found = true;
        }

        Assert.isTrue(found);

        // Test modification
        for (e in query) {
            e.velAbstractOverTypedef.x = 7.0;
            e.velAbstractOverTypedef.y = 8.0;
        }

        Assert.equals(7.0, world.velAbstractOverTypedef[6].x);
        Assert.equals(8.0, world.velAbstractOverTypedef[6].y);
    }

    public function testAbstractOverTypedefSimpleArray() {
        // Test abstract wrapping typedef simple array
        var query = new hxbitecs.HxQuery<TypedefComponentWorld, [posAbstractOverSimple]>(world);

        var found = false;
        for (e in query) {
            Assert.equals(7, e.eid);
            Assert.equals(80.0, e.posAbstractOverSimple);
            found = true;
        }

        Assert.isTrue(found);

        // Test modification
        for (e in query) {
            e.posAbstractOverSimple = 190.0;
        }

        Assert.equals(190.0, world.posAbstractOverSimple[7]);
    }

    public function testTypedefWithHxAddComponent() {
        // Test Hx.addComponent with typedef components
        var e8 = Bitecs.addEntity(world);
        var wrapper = hxbitecs.Hx.addComponent(world, e8, world.posSoA, { x: 60.0, y: 70.0 });

        Assert.equals(60.0, world.posSoA.x[e8]);
        Assert.equals(70.0, world.posSoA.y[e8]);

        // Verify wrapper is returned and works
        Assert.equals(60.0, wrapper.x);
        Assert.equals(70.0, wrapper.y);
        wrapper.x = 65.0;
        Assert.equals(65.0, world.posSoA.x[e8]);

        // Test with AoS typedef
        var e9 = Bitecs.addEntity(world);
        var wrapperAoS = hxbitecs.Hx.addComponent(world, e9, world.velAoS, { x: 8.0, y: 9.0 });

        Assert.equals(8.0, world.velAoS[e9].x);
        Assert.equals(9.0, world.velAoS[e9].y);

        // Verify wrapper works for AoS typedef
        Assert.equals(8.0, wrapperAoS.x);
        Assert.equals(9.0, wrapperAoS.y);
        wrapperAoS.y = 10.0;
        Assert.equals(10.0, world.velAoS[e9].y);
    }


}

// Typedef for simple array
typedef PositionSimple = Array<Float>;

// Typedef for SoA
typedef PositionSoA = {

    var x:Array<Float>;
    var y:Array<Float>;

}

// Typedef for AoS
typedef VelocityAoS = Array<{x:Float, y:Float}>;

// Typedef for AoS with many fields
typedef PlayerData = Array<{
    var id:Int;
    var name:String;
    var score:Int;
    var level:Int;
    var health:Float;
    var mana:Float;
    var isActive:Bool;
}>;

// Abstract for SoA (similar to typedef but with additional features)

@:forward
abstract AbstractPosition({x:Array<Float>, y:Array<Float>}) {
    public inline function new() {
        this = { x: new Array<Float>(), y: new Array<Float>() };
    }

}

// Abstract over typedef SoA

@:forward
abstract AbstractPositionOverTypedefSoA(PositionSoA) {

    public inline function new() {
        this = { x: new Array<Float>(), y: new Array<Float>() };
    }
}

// Abstract over typedef AoS

@:forward
@:arrayAccess
abstract AbstractVelocityOverTypedefAoS(VelocityAoS) {

    public inline function new() {
        this = new Array<{x:Float, y:Float}>();
    }

}

// Abstract over typedef simple array

@:forward
@:arrayAccess
abstract AbstractPositionOverSimple(PositionSimple) {

    public inline function new() {
        this = new Array<Float>();
    }

}

@:publicFields class TypedefComponentWorld {

    function new() { }

    // Simple array typedef component
    var posSimple:PositionSimple = new Array<Float>();

    // SoA typedef component
    var posSoA:PositionSoA = { x: new Array<Float>(), y: new Array<Float>() };

    // AoS typedef component
    var velAoS:VelocityAoS = new Array<{x:Float, y:Float}>();

    // AoS typedef with many fields
    var playerData:PlayerData = [];

    // Abstract SoA component
    var posAbstract = new AbstractPosition();

    // Abstract over typedef components
    var posAbstractOverTypedef = new AbstractPositionOverTypedefSoA();
    var velAbstractOverTypedef = new AbstractVelocityOverTypedefAoS();
    var posAbstractOverSimple = new AbstractPositionOverSimple();

}

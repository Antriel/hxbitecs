package macros;

import hxbitecs.Hx;

class TestInitComponent extends Test {

    var world:InitComponentWorld;

    public function setup() {
        world = Bitecs.createWorld(new InitComponentWorld());
    }

    public function teardown() {
        Bitecs.deleteWorld(world);
    }

    public function testSoAFullInitialization() {
        // Test full initialization of SoA component with all fields
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.pos, { x: 10.0, y: 20.0 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.equals(10.0, world.pos.x[eid]);
        Assert.equals(20.0, world.pos.y[eid]);

        // Verify wrapper is returned and works correctly
        Assert.equals(10.0, wrapper.x);
        Assert.equals(20.0, wrapper.y);

        // Verify wrapper can modify values
        wrapper.x = 15.0;
        Assert.equals(15.0, world.pos.x[eid]);
    }

    public function testSoAPartialInitialization() {
        // Test partial initialization - only some fields
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.pos, { x: 15.0 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.equals(15.0, world.pos.x[eid]);
        // y should be uninitialized (0.0 or whatever default)

        // Verify wrapper works and can set remaining fields
        Assert.equals(15.0, wrapper.x);
        wrapper.y = 25.0;
        Assert.equals(25.0, world.pos.y[eid]);
    }

    public function testAoSInitialization() {
        // Test Array of Structs initialization
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.health, { hp: 100, maxHp: 150 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.health));
        Assert.equals(100, world.health[eid].hp);
        Assert.equals(150, world.health[eid].maxHp);

        // Verify wrapper works for AoS
        Assert.equals(100, wrapper.hp);
        Assert.equals(150, wrapper.maxHp);
        wrapper.hp = 75;
        Assert.equals(75, world.health[eid].hp);
    }

    public function testSimpleArrayInitialization() {
        // Test simple array component initialization
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.damage, 50);

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.damage));
        Assert.equals(50, world.damage[eid]);

        // Verify wrapper works for SimpleArray
        Assert.equals(50, wrapper.value);
        wrapper.value = 75;
        Assert.equals(75, world.damage[eid]);
    }

    public function testSimpleArrayWithoutInit() {
        // Test adding simple array component without initialization
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.damage);

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.damage));
        // Value should be whatever the default is (0 or undefined behavior)

        // Verify wrapper can set values
        wrapper.value = 100;
        Assert.equals(100, world.damage[eid]);
    }

    public function testTagComponent() {
        // Test tag component (no initialization allowed)
        var eid = Bitecs.addEntity(world);

        Hx.addComponent(world, eid, world.isAlive);

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.isAlive));
    }

    public function testDirectComponentReference() {
        // Test using direct component reference (not world.component)
        var eid = Bitecs.addEntity(world);
        var pos = world.pos;

        Hx.addComponent(world, eid, pos, { x: 25.0, y: 35.0 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.equals(25.0, world.pos.x[eid]);
        Assert.equals(35.0, world.pos.y[eid]);
    }

    public function testMultipleComponentsOnSameEntity() {
        // Test adding multiple components to same entity
        var eid = Bitecs.addEntity(world);

        Hx.addComponent(world, eid, world.pos, { x: 5.0, y: 10.0 });
        Hx.addComponent(world, eid, world.vel, { x: 1.0, y: 2.0 });
        Hx.addComponent(world, eid, world.damage, 30);
        Hx.addComponent(world, eid, world.isAlive);

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.isTrue(Bitecs.hasComponent(world, eid, world.vel));
        Assert.isTrue(Bitecs.hasComponent(world, eid, world.damage));
        Assert.isTrue(Bitecs.hasComponent(world, eid, world.isAlive));

        Assert.equals(5.0, world.pos.x[eid]);
        Assert.equals(10.0, world.pos.y[eid]);
        Assert.equals(1.0, world.vel.x[eid]);
        Assert.equals(2.0, world.vel.y[eid]);
        Assert.equals(30, world.damage[eid]);
    }

    public function testModifyAfterInit() {
        // Test that values can be modified after initialization
        var eid = Bitecs.addEntity(world);

        Hx.addComponent(world, eid, world.pos, { x: 100.0, y: 200.0 });

        Assert.equals(100.0, world.pos.x[eid]);
        Assert.equals(200.0, world.pos.y[eid]);

        // Modify values
        world.pos.x[eid] = 999.0;
        world.pos.y[eid] = 888.0;

        Assert.equals(999.0, world.pos.x[eid]);
        Assert.equals(888.0, world.pos.y[eid]);
    }

    public function testQueryAfterInit() {
        // Test that initialized components work correctly in queries
        var eid1 = Bitecs.addEntity(world);
        var eid2 = Bitecs.addEntity(world);
        var eid3 = Bitecs.addEntity(world);

        Hx.addComponent(world, eid1, world.pos, { x: 1.0, y: 2.0 });
        Hx.addComponent(world, eid2, world.pos, { x: 3.0, y: 4.0 });
        Hx.addComponent(world, eid2, world.vel, { x: 0.5, y: 0.5 });
        Hx.addComponent(world, eid3, world.vel, { x: 1.0, y: 1.0 });

        // Query for entities with pos
        var posQuery = Bitecs.query(world, [world.pos]);
        Assert.equals(2, posQuery.asType1.length);

        // Query for entities with both pos and vel
        var posVelQuery = Bitecs.query(world, [world.pos, world.vel]);
        Assert.equals(1, posVelQuery.asType1.length);
        Assert.equals(eid2, posVelQuery.asType1[0]);
    }

    public function testWithoutInitializer() {
        // Test that components can be added without initializer
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.pos);

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        // Values will be whatever the default is

        // Verify wrapper is returned and can set values
        wrapper.x = 50.0;
        wrapper.y = 60.0;
        Assert.equals(50.0, world.pos.x[eid]);
        Assert.equals(60.0, world.pos.y[eid]);
    }

    public function testTypeSafety() {
        // This test demonstrates that type checking works automatically
        var eid = Bitecs.addEntity(world);

        // This should work - correct types
        Hx.addComponent(world, eid, world.pos, { x: 10.0, y: 20.0 });
        Assert.equals(10.0, world.pos.x[eid]);

        // Type mismatches will be caught by Haxe compiler at compile time
        // Hx.addComponent(world, eid, world.pos, {x: "string", y: 20.0}); // Would fail to compile
        // Hx.addComponent(world, eid, world.damage, {value: 10}); // Would fail to compile
    }

    // The following tests would cause compile-time errors and are commented out:
    // public function testExtraFieldError() {
    //     var eid = Bitecs.addEntity(world);
    //     // Error: Field "z" does not exist in component
    //     Hx.addComponent(world, eid, world.pos, { x: 10.0, y: 20.0, z: 30.0 });
    // }
    // public function testTagWithInitError() {
    //     var eid = Bitecs.addEntity(world);
    //     // Error: Tag components have no fields and cannot be initialized
    //     Hx.addComponent(world, eid, world.isAlive, { value: true });
    // }
    // public function testWrongTypeError() {
    //     var eid = Bitecs.addEntity(world);
    //     // Error: Type mismatch - x should be Float, not String
    //     Hx.addComponent(world, eid, world.pos, { x: "not a number", y: 20.0 });
    // }

}

@:publicFields class InitComponentWorld {

    function new() { }

    // SoA Float components
    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };

    // AoS component
    var health = new Array<{hp:Int, maxHp:Int}>();

    // Simple array component
    var damage = new Array<Int>();

    // Tag component
    var isAlive = {};

}

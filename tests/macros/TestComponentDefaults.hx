package macros;

import hxbitecs.Hx;
import hxbitecs.SoA;

class TestComponentDefaults extends Test {

    var world:DefaultsWorld;

    public function setup() {
        world = Bitecs.createWorld(new DefaultsWorld());
    }

    public function teardown() {
        Bitecs.deleteWorld(world);
    }

    public function testSoAWithDefaultsPartialInit() {
        // Test partial initialization - some fields provided, some use defaults
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.pos, { x: 10.0 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.equals(10.0, world.pos.x[eid]); // Provided value
        Assert.equals(-1.0, world.pos.y[eid]); // Default value
        Assert.equals(5.0, world.pos.z[eid]); // Default value

        // Verify wrapper
        Assert.equals(10.0, wrapper.x);
        Assert.equals(-1.0, wrapper.y);
        Assert.equals(5.0, wrapper.z);
    }

    public function testSoAWithDefaultsFullInit() {
        // Test full initialization - all fields provided, defaults ignored
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.pos, { x: 20.0, y: 30.0, z: 40.0 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.equals(20.0, world.pos.x[eid]);
        Assert.equals(30.0, world.pos.y[eid]);
        Assert.equals(40.0, world.pos.z[eid]);

        // Verify wrapper
        Assert.equals(20.0, wrapper.x);
        Assert.equals(30.0, wrapper.y);
        Assert.equals(40.0, wrapper.z);
    }

    public function testSoAWithDefaultsEmptyInit() {
        // Test empty initialization - all fields use defaults
        var eid = Bitecs.addEntity(world);
        var wrapper = Hx.addComponent(world, eid, world.pos, { });
        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.equals(0.0, world.pos.x[eid]); // Default
        Assert.equals(-1.0, world.pos.y[eid]); // Default
        Assert.equals(5.0, world.pos.z[eid]); // Default
        // Verify wrapper
        Assert.equals(0.0, wrapper.x);
        Assert.equals(-1.0, wrapper.y);
        Assert.equals(5.0, wrapper.z);
    }

    public function testSoAWithDefaultsNoInit() {
        // Test without initialization object - should use defaults
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.pos);

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.equals(0.0, world.pos.x[eid]); // Default
        Assert.equals(-1.0, world.pos.y[eid]); // Default
        Assert.equals(5.0, world.pos.z[eid]); // Default

        // Verify wrapper can modify values
        wrapper.x = 100.0;
        Assert.equals(100.0, world.pos.x[eid]);
    }

    public function testAoSWithDefaults() {
        // Test Array of Structs with defaults
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.health, { hp: 50 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.health));
        Assert.equals(50, world.health[eid].hp); // Provided
        Assert.equals(100, world.health[eid].maxHp); // Default

        // Verify wrapper
        Assert.equals(50, wrapper.hp);
        Assert.equals(100, wrapper.maxHp);
    }

    public function testAoSWithDefaultsEmptyInit() {
        // Test AoS with empty init - all defaults
        var eid = Bitecs.addEntity(world);
        var wrapper = Hx.addComponent(world, eid, world.health, { });
        Assert.isTrue(Bitecs.hasComponent(world, eid, world.health));
        Assert.equals(100, world.health[eid].hp); // Default
        Assert.equals(100, world.health[eid].maxHp); // Default
        // Verify wrapper
        Assert.equals(100, wrapper.hp);
        Assert.equals(100, wrapper.maxHp);
    }

    public function testWithoutTypedefNoDefaults() {
        // Test component without typedef - should work as before (no defaults)
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.vel, { x: 1.0, y: 2.0 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.vel));
        Assert.equals(1.0, world.vel.x[eid]);
        Assert.equals(2.0, world.vel.y[eid]);

        // Verify wrapper
        Assert.equals(1.0, wrapper.x);
        Assert.equals(2.0, wrapper.y);
    }

    public function testMultipleComponentsWithDefaults() {
        // Test multiple components on same entity with mixed defaults
        var eid = Bitecs.addEntity(world);

        Hx.addComponent(world, eid, world.pos, { x: 5.0 }); // Uses defaults for y, z
        Hx.addComponent(world, eid, world.health); // Uses all defaults (no init)
        Hx.addComponent(world, eid, world.vel, { x: 1.0, y: 2.0 }); // No defaults

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.pos));
        Assert.isTrue(Bitecs.hasComponent(world, eid, world.health));
        Assert.isTrue(Bitecs.hasComponent(world, eid, world.vel));

        Assert.equals(5.0, world.pos.x[eid]);
        Assert.equals(-1.0, world.pos.y[eid]);
        Assert.equals(5.0, world.pos.z[eid]);

        Assert.equals(100, world.health[eid].hp);
        Assert.equals(100, world.health[eid].maxHp);

        Assert.equals(1.0, world.vel.x[eid]);
        Assert.equals(2.0, world.vel.y[eid]);
    }

    public function testQueryAfterDefaultsInit() {
        // Test that components with defaults work correctly in queries
        var eid1 = Bitecs.addEntity(world);
        var eid2 = Bitecs.addEntity(world);
        var eid3 = Bitecs.addEntity(world);

        Hx.addComponent(world, eid1, world.pos, { x: 1.0 }); // y=-1, z=5 (defaults)
        Hx.addComponent(world, eid2, world.pos, { x: 2.0, y: 3.0 }); // z=5 (default)
        Hx.addComponent(world, eid3, world.pos, { x: 3.0, y: 4.0, z: 6.0 }); // No defaults

        // Query for entities with pos
        var posQuery = Bitecs.query(world, [world.pos]);
        Assert.equals(3, posQuery.asType1.length);

        // Verify values
        Assert.equals(1.0, world.pos.x[eid1]);
        Assert.equals(-1.0, world.pos.y[eid1]);
        Assert.equals(5.0, world.pos.z[eid1]);

        Assert.equals(2.0, world.pos.x[eid2]);
        Assert.equals(3.0, world.pos.y[eid2]);
        Assert.equals(5.0, world.pos.z[eid2]);

        Assert.equals(3.0, world.pos.x[eid3]);
        Assert.equals(4.0, world.pos.y[eid3]);
        Assert.equals(6.0, world.pos.z[eid3]);
    }

    public function testDefaultsWithMixedTypes() {
        // Test that defaults work with different numeric types
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.stats, { strength: 15 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.stats));
        Assert.equals(15, world.stats.strength[eid]); // Provided
        Assert.equals(10, world.stats.dexterity[eid]); // Default
        Assert.equals(8, world.stats.intelligence[eid]); // Default
        Assert.equals(1.5, world.stats.speed[eid]); // Default (Float)

        // Verify wrapper
        Assert.equals(15, wrapper.strength);
        Assert.equals(10, wrapper.dexterity);
        Assert.equals(8, wrapper.intelligence);
        Assert.equals(1.5, wrapper.speed);
    }

    public function testWrapperModificationWithDefaults() {
        // Test that wrapper returned from addComponent with defaults can modify values
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.pos, { x: 10.0 });

        // Modify via wrapper
        wrapper.x = 50.0;
        wrapper.y = 60.0;
        wrapper.z = 70.0;

        // Verify changes
        Assert.equals(50.0, world.pos.x[eid]);
        Assert.equals(60.0, world.pos.y[eid]);
        Assert.equals(70.0, world.pos.z[eid]);
    }

    public function testPartialDefaultsInTypeDef() {
        // Test typedef with defaults for some fields but not all
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.partialDefaults, { a: 5 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.partialDefaults));
        Assert.equals(5, world.partialDefaults.a[eid]); // Provided
        Assert.equals(99, world.partialDefaults.b[eid]); // Default
        // c should be uninitialized (no default provided for it)
    }

    public function testPerFieldDefaultsSoA() {
        // Test per-field @:default metadata for SoA components
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.perFieldPos, { x: 10.0 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.perFieldPos));
        Assert.equals(10.0, world.perFieldPos.x[eid]); // Provided
        Assert.equals(100.0, world.perFieldPos.y[eid]); // Per-field default
        Assert.equals(200.0, world.perFieldPos.z[eid]); // Per-field default

        // Verify wrapper
        Assert.equals(10.0, wrapper.x);
        Assert.equals(100.0, wrapper.y);
        Assert.equals(200.0, wrapper.z);
    }

    public function testPerFieldDefaultsAoS() {
        // Test per-field @:default metadata for AoS components
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.perFieldHealth, { current: 50 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.perFieldHealth));
        Assert.equals(50, world.perFieldHealth[eid].current); // Provided
        Assert.equals(100, world.perFieldHealth[eid].max); // Per-field default

        // Verify wrapper
        Assert.equals(50, wrapper.current);
        Assert.equals(100, wrapper.max);
    }

    public function testMixedDefaultsSoA() {
        // Test typedef-level @:defaults mixed with field-level @:default
        // Field-level should override typedef-level
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.mixedDefaults);

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.mixedDefaults));
        Assert.equals(1.0, world.mixedDefaults.a[eid]); // Typedef default
        Assert.equals(999.0, world.mixedDefaults.b[eid]); // Field default overrides typedef
        Assert.equals(3.0, world.mixedDefaults.c[eid]); // Typedef default

        // Verify wrapper
        Assert.equals(1.0, wrapper.a);
        Assert.equals(999.0, wrapper.b);
        Assert.equals(3.0, wrapper.c);
    }

    public function testMixedDefaultsAoS() {
        // Test typedef-level @:defaults mixed with field-level @:default for AoS
        var eid = Bitecs.addEntity(world);

        var wrapper = Hx.addComponent(world, eid, world.mixedHealthAoS, { current: 75 });

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.mixedHealthAoS));
        Assert.equals(75, world.mixedHealthAoS[eid].current); // Provided
        Assert.equals(150, world.mixedHealthAoS[eid].max); // Field default overrides typedef

        // Verify wrapper
        Assert.equals(75, wrapper.current);
        Assert.equals(150, wrapper.max);
    }

}

// Typedef with defaults for SoA

@:defaults({ x: 0.0, y: -1.0, z: 5.0 })
typedef Vec3 = {x:Float, y:Float, z:Float};

// Typedef with defaults for AoS

@:defaults({ hp: 100, maxHp: 100 })
typedef HealthData = {hp:Int, maxHp:Int};

// Typedef with mixed types and defaults

@:defaults({ strength: 10, dexterity: 10, intelligence: 8, speed: 1.5 })
typedef StatsData = {strength:Int, dexterity:Int, intelligence:Int, speed:Float};

// Typedef with partial defaults (only some fields have defaults)

@:defaults({ b: 99 })
typedef PartialData = {a:Int, b:Int, c:Int};

// Typedef with per-field @:default metadata (no typedef-level @:defaults)
typedef PerFieldVec3 = {

    var x:Float;
    @:default(100.0) var y:Float;
    @:default(200.0) var z:Float;

};

// Typedef with per-field @:default for AoS
typedef PerFieldHealth = {

    var current:Int;
    @:default(100) var max:Int;

};

// Typedef with both typedef-level @:defaults and field-level @:default
// Field-level should win

@:defaults({ a: 1.0, b: 2.0, c: 3.0 })
typedef MixedDefaultsData = {

    var a:Float;
    @:default(999.0) var b:Float; // Overrides typedef default of 2.0
    var c:Float;

};

// Typedef with both for AoS

@:defaults({ current: 50, max: 100 })
typedef MixedHealthData = {

    var current:Int;
    @:default(150) var max:Int; // Overrides typedef default of 100

};

@:publicFields class DefaultsWorld {

    function new() { }

    // SoA component with defaults (via typedef)
    var pos:SoA<Vec3> = new SoA<Vec3>();

    // AoS component with defaults (via typedef)
    var health:Array<HealthData> = new Array<HealthData>();

    // SoA component without typedef (no defaults)
    var vel = { x: new Array<Float>(), y: new Array<Float>() };

    // SoA component with mixed type defaults
    var stats:SoA<StatsData> = new SoA<StatsData>();

    // SoA component with partial defaults
    var partialDefaults:SoA<PartialData> = new SoA<PartialData>();

    // SoA component with per-field defaults
    var perFieldPos:SoA<PerFieldVec3> = new SoA<PerFieldVec3>();

    // AoS component with per-field defaults
    var perFieldHealth:Array<PerFieldHealth> = new Array<PerFieldHealth>();

    // SoA component with mixed typedef and field defaults
    var mixedDefaults:SoA<MixedDefaultsData> = new SoA<MixedDefaultsData>();

    // AoS component with mixed typedef and field defaults
    var mixedHealthAoS:Array<MixedHealthData> = new Array<MixedHealthData>();

}

package macros;

import hxbitecs.Hx;

/**
 * Test for AoS components added without initialization values.
 *
 * This tests the scenario where:
 * 1. An AoS component is added without providing initialization values
 * 2. The component is then accessed via Hx.get()
 * 3. Setting a field on the result should work (but currently fails
 *    because the array slot isn't initialized to an empty object)
 *
 * Related to pattern:
 *   if (!Bitecs.hasComponent(world, eid, world.stagger))
 *       Hx.addComponent(world, eid, world.stagger);
 *   final stagger = Hx.get(eid, world.stagger);
 *   stagger.isActive = false;  // Fails - array slot is undefined
 */
class TestAoSWithoutInit extends Test {

    var world:AoSWithoutInitWorld;

    public function setup() {
        world = Bitecs.createWorld(new AoSWithoutInitWorld());
    }

    public function teardown() {
        Bitecs.deleteWorld(world);
    }

    public function testAoSAddWithoutInitThenGet() {
        // This is the problematic scenario:
        // Add component without initialization, then access via Hx.get()
        var eid = Bitecs.addEntity(world);

        // Add component without initialization data
        Hx.addComponent(world, eid, world.status);

        Assert.isTrue(Bitecs.hasComponent(world, eid, world.status));

        // Get the component via Hx.get
        var status = Hx.get(eid, world.status);

        // This should work but currently fails because the object wasn't initialized
        status.isActive = false;

        // Verify the value was set
        Assert.isFalse(status.isActive);
        Assert.isFalse(world.status[eid].isActive);
    }

    public function testAoSAddWithoutInitThenGetWithBoolField() {
        // Specifically test the Bool field scenario from the bug report
        var eid = Bitecs.addEntity(world);

        // Common pattern: check if component exists, add if not, then access
        if (!Bitecs.hasComponent(world, eid, world.status)) {
            Hx.addComponent(world, eid, world.status);
        }

        var status = Hx.get(eid, world.status);
        status.isActive = true;

        Assert.isTrue(status.isActive);
        Assert.isTrue(world.status[eid].isActive);
    }

    public function testAoSAddWithoutInitMultipleFields() {
        // Test with multiple fields
        var eid = Bitecs.addEntity(world);

        Hx.addComponent(world, eid, world.state);

        var state = Hx.get(eid, world.state);

        // All fields should be settable even without initialization
        state.value = 42;
        state.isEnabled = true;
        state.progress = 0.5;

        Assert.equals(42, state.value);
        Assert.isTrue(state.isEnabled);
        Assert.equals(0.5, state.progress);

        // Verify directly on component array
        Assert.equals(42, world.state[eid].value);
        Assert.isTrue(world.state[eid].isEnabled);
        Assert.equals(0.5, world.state[eid].progress);
    }

    public function testAoSAddWithInitVsWithoutInit() {
        // Compare behavior: with init vs without init
        var eid1 = Bitecs.addEntity(world);
        var eid2 = Bitecs.addEntity(world);

        // With initialization - works fine
        Hx.addComponent(world, eid1, world.status, { isActive: true });
        var status1 = Hx.get(eid1, world.status);
        Assert.isTrue(status1.isActive);

        // Without initialization - should also work
        Hx.addComponent(world, eid2, world.status);
        var status2 = Hx.get(eid2, world.status);
        // Should be able to set value
        status2.isActive = false;
        Assert.isFalse(status2.isActive);
    }

    public function testAoSAddReturnWrapperWithoutInit() {
        // Test that the wrapper returned from addComponent works without init
        var eid = Bitecs.addEntity(world);

        // addComponent returns a wrapper - test that it works even without init
        var wrapper = Hx.addComponent(world, eid, world.status);

        // This should work - set through returned wrapper
        wrapper.isActive = true;

        Assert.isTrue(wrapper.isActive);
        Assert.isTrue(world.status[eid].isActive);
    }

}

@:publicFields class AoSWithoutInitWorld {

    function new() { }

    // AoS component with single Bool field (matching the bug report pattern)
    var status = new Array<{isActive:Bool}>();

    // AoS component with multiple fields for more thorough testing
    var state = new Array<{value:Int, isEnabled:Bool, progress:Float}>();

}

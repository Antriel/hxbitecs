package cases;

import bitecs.*;

class TestWorldMacro extends Test {

    public function testSimple() {
        var world = new World<MyComponent1>();
        Assert.notNull(world.myComponent1);
    }

    public function testRename() {
        var w = new World<MyComponent1, {comp2:MyComponent2, comp3:MyComponent3}>();
        Assert.notNull(w.myComponent1);
        Assert.notNull(w.comp2);
        Assert.notNull(w.comp3);
        Assert.notEquals(w.comp2, w.comp3); // Test aliasing works.
    }

    public function testApi() {
        var w = new World<MyComponent1, {comp2:MyComponent2}>();
        var eid = w.addEntity();
        w.addComponent([MyComponent1, MyComponent2], eid);
        Assert.isTrue(w.hasComponent(MyComponent1, eid));
        Assert.isTrue(w.hasComponent(MyComponent2, eid));
        Assert.same({ myComponent1: true, comp2: true }, w.hasComponent([MyComponent1, MyComponent2], eid));
        w.removeComponent(MyComponent1, eid);
        Assert.isFalse(w.hasComponent(MyComponent1, eid));
        Assert.isTrue(w.hasComponent(MyComponent2, eid));
        Assert.same({ myComponent1: false, comp2: true }, w.hasComponent([MyComponent1, MyComponent2], eid));
        Assert.same([w.comp2], w.getEntityComponents(eid));
        Assert.isTrue(w.entityExists(eid));
        w.removeEntity(eid);
        Assert.isFalse(w.entityExists(eid));
    }

    public function testWorldOf() {
        // For generic systems wanting a world that contains some components, but without needing to specify the full type.
        var w:World.WorldOf<MyComponent1> = new World<MyComponent1, {comp3:MyComponent3}>();
        Assert.notNull(w.myComponent1);
    }

}

class MyComponent1 { }

class MyComponent2 { }

typedef MyComponent3 = MyComponent2;

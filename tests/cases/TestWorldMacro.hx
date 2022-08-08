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
        Assert.isTrue(w.hasAllComponents([MyComponent1, MyComponent2], eid));
        w.removeComponent(MyComponent1, eid);
        Assert.isFalse(w.hasComponent(MyComponent1, eid));
        Assert.isTrue(w.hasComponent(MyComponent2, eid));
        Assert.same({ myComponent1: false, comp2: true }, w.hasComponent([MyComponent1, MyComponent2], eid));
        Assert.same([w.comp2], w.getEntityComponents(eid));
        Assert.isFalse(w.hasAllComponents([MyComponent1, MyComponent2], eid));
        Assert.isTrue(w.entityExists(eid));
        w.removeEntity(eid);
        Assert.isFalse(w.entityExists(eid));
    }

    public function testWorldOf() {
        // For generic systems wanting a world that contains some components, but without needing to specify the full type.
        var w:World.WorldOf<MyComponent1> = new World<MyComponent1, {comp3:MyComponent3}>();
        Assert.notNull(w.myComponent1);
    }

    public function testWorldOfExtensions() {
        var fullWorld = new World<MyComponent1, {comp2:MyComponent2, comp3:MyComponent3}>();
        function oneWorld(w:World.WorldOf<MyComponent1>) {
            Assert.notNull(w.myComponent1);
            w.addEntity();
        }
        function twoWorld(w:World.WorldOf<MyComponent1, {comp2:MyComponent2}>) {
            Assert.notNull(w.myComponent1);
            Assert.notNull(w.comp2);
            w.addEntity();
            oneWorld(w);
        }
        twoWorld(fullWorld);
    }

    public function testConstructorArgs() {
        var w = new World<MyComponent4>();
        var e = w.addEntity();
        var c = w.addComponent(MyComponent4, e, { a: 10 });
        Assert.equals(10, w.myComponent4.a[e]);
        Assert.isTrue(c.b);
        e = w.addEntity();
        c = w.addComponent(MyComponent4, e, { a: 1, b: false });
        Assert.equals(1, c.a);
        Assert.isFalse(c.b);
    }

}

class MyComponent1 implements IComponent { }

class MyComponent2 implements IComponent { }

typedef MyComponent3 = MyComponent2;

class MyComponent4 implements IComponent {

    public var a:Int;
    public var b:Bool;

    public function new(a:Int, b:Bool = true) {
        this.a = a;
        this.b = b;
    }

}

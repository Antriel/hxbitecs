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

}

private class MyComponent1 { }

private class MyComponent2 { }

typedef MyComponent3 = MyComponent2;

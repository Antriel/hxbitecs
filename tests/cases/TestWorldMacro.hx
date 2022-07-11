package cases;

import bitecs.*;

class TestWorldMacro extends Test {

    public function testSimple() {
        var world = new MyWorld();
        Assert.notNull(world.myComponent1);
        Assert.notNull(world.myComponent2);
    }

}

private class MyWorld extends World {

    var s:MySystem1; // Test that we can extract types from fields.

    public function new() {
        @:keep var foo = [(null:MySystem2)]; // Test that we can extract types from constructor.
    }

}

private class MySystem1 {

    @:keep var c:Query<MyComponent1>; // Just making sure it's typed. In practice we use `Query`.

}

private class MySystem2 {

    @:keep var c:Query<MyComponent1, MyComponent2>;

}

private class MyComponent1 { }

private class MyComponent2 { }

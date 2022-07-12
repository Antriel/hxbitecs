package cases;

class TestComponentMacro extends Test {

    public function testSimple() {
        var w = new MyWorld();
        Assert.isTrue(Reflect.hasField(w.simpleComponent, 'float'));
        Assert.isTrue(Reflect.hasField(w.simpleComponent, 'int'));
        Assert.isTrue(Reflect.hasField(w.simpleComponent, 'bool'));
    }

}

private class MyWorld extends World {

    public var q:Query<SimpleComponent>;

    public function new() {
        super(100);
    }

}

private class SimpleComponent {

    public var float:Float;
    public var int:Int;
    public var bool:Bool;

}

// TODO initialized values.
// TODO specifying precision.
// TODO non-value types mapping.
// TODO component wrappers.

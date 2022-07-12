package cases;

class TestComponentMacro extends Test {

    public function testSimple() {
        var w = new MyWorld();
        Assert.isTrue(Reflect.hasField(w.simpleComponent, 'float'));
        Assert.isTrue(Reflect.hasField(w.simpleComponent, 'int'));
        Assert.isTrue(Reflect.hasField(w.simpleComponent, 'bool'));

        w.simplePrecisionComponent.float[0] = 16777217; // Over max safe int for f32.
        Assert.notEquals(16777217, w.simplePrecisionComponent.float[0]);
        w.simplePrecisionComponent.float[0] = 16777215;
        Assert.equals(16777215, w.simplePrecisionComponent.float[0]);
        w.simplePrecisionComponent.int[0] = -1;
        Assert.equals(255, w.simplePrecisionComponent.int[0]);
        w.simplePrecisionComponent.int[0] = 256;
        Assert.equals(0, w.simplePrecisionComponent.int[0]);
        w.simplePrecisionComponent.int[0] = 129;
        Assert.equals(129, w.simplePrecisionComponent.int[0]);

        Assert.isOfType(w.stringComponent.string, js.lib.Map);
    }

}

private class MyWorld extends World {

    public var simpleQ:Query<SimpleComponent>;
    public var precisionQ:Query<SimplePrecisionComponent>;
    public var stringQ:Query<StringComponent>;

}

private class SimpleComponent {

    public var float:Float;
    public var int:Int;
    public var bool:Bool;

}

private class SimplePrecisionComponent {

    @:bitecs.type(f32) public var float:Float;
    @:bitecs.type(ui8) public var int:Int;

}

private class StringComponent {

    public var int:Int;
    public var string:String;

}

// TODO initialized values.
// TODO component wrappers.

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

    public function testInitSimpleValues() {
        var w = new MyWorld();
        var e1 = Bitecs.addEntity(w); // Need to make and remove multiple, so that bitECS reuses an Entity.
        var e2 = Bitecs.addEntity(w);
        Bitecs.addComponent(w, w.simpleComponent, e1);
        w.simpleComponent.float[e1] = 25;
        Bitecs.addComponent(w, w.simpleComponent, e2);
        w.simpleComponent.float[e2] = 25;
        Bitecs.removeEntity(w, e1);
        Bitecs.removeEntity(w, e2);
        while (Bitecs.addEntity(w) != e1) { };
        while (Bitecs.addEntity(w) != e2) { };
        Bitecs.addComponent(w, w.simpleComponent, e1, true); // bitECS resets the value to 0.
        Assert.notEquals(25, w.simpleComponent.float[e1]);
        w.addComponent(SimpleComponent, e2); // Our wrapper initializes the values.
        Assert.equals(10, w.simpleComponent.float[e2]);
    }

    public function testMapWrapper() {
        var w = new MyWorld();
        var e = Bitecs.addEntity(w);
        var stringComp = w.addComponent(StringComponent, e);
        Assert.equals('hello', stringComp.string);
        stringComp.string += ' world';
        Assert.equals('hello world', stringComp.string);
    }

    public function testFunctions() {
        var w = new MyWorld();
        var e = Bitecs.addEntity(w);
        var comps = w.addComponent([SimpleComponent, StringComponent], e);
        comps.simpleComponent.setTo(1);
        Assert.equals(1, comps.simpleComponent.int);
        Assert.equals(1, comps.simpleComponent.float);
        comps.stringComponent.int = 123;
        Assert.equals('hello123', comps.stringComponent.appendInt());
        Assert.equals('hello123', comps.stringComponent.string);
    }

    public function testComplex() {
        var w = new World<ComplexComponent>();
        var e = Bitecs.addEntity(w);
        var c = w.addComponent(ComplexComponent, e, { initVal: 10 }); // Should ask for ctr init vars.
        Assert.equals(10, c.initVal);
        Assert.isTrue(c.simpleFunc());
        c.customSetter('world');
        Assert.equals('hello world', c.customSet);
        // c.initVal = 10; // Should be a compiler error.
        // c.customSet = 'foo'; // Also a compiler error.
    }

}

private typedef MyWorld = World<SimpleComponent, SimplePrecisionComponent, StringComponent>;

class SimpleComponent implements IComponent {

    public var float:Float = 10;
    public var int:Int;
    public var bool:Bool;

    public inline function setTo(v:Int) {
        float = v;
        int = v;
    }

}

class SimplePrecisionComponent implements IComponent {

    @:bitecs.type(f32) public var float:Float;
    @:bitecs.type(ui8) public var int:Int;

}

class StringComponent implements IComponent {

    public var int:Int;
    public var string:String = "hello";

    public inline function appendInt() {
        return string = string + int;
    }

}

class ComplexComponent implements IComponent {

    public var writeable:Int = 1;
    public final initVal:Int;
    public var customSet(default, null):String;

    public function new(initVal:Int) { // Required init param.
        this.initVal = initVal;
    }

    public inline function simpleFunc() return customSet == null;

    public inline function customSetter(name:String) {
        customSet = 'hello $name';
    }

}

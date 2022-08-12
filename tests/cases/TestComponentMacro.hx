package cases;

import data.FooBar;

class TestComponentMacro extends Test {

    public function testSimple() {
        var w = new MyWorld(100);
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
        var w = new MyWorld(10);
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
        var w = new MyWorld(100);
        var e = Bitecs.addEntity(w);
        var stringComp = w.addComponent(StringComponent, e);
        Assert.equals('hello', stringComp.string);
        stringComp.string += ' world';
        Assert.equals('hello world', stringComp.string);
    }

    public function testFunctions() {
        var w = new MyWorld(100);
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
        var w = new World<ComplexComponent>(100);
        var e = Bitecs.addEntity(w);
        var c = w.addComponent(ComplexComponent, e, { initVal: 10 }); // Should ask for ctr init vars.
        Assert.equals(10, c.initVal);
        Assert.isTrue(c.simpleFunc());
        c.customSetter('world');
        Assert.equals('hello world', c.customSet);
        // c.initVal = 10; // Should be a compiler error.
        // c.customSet = 'foo'; // Also a compiler error.
    }

    public function testEntityType() {
        var w = new World<EntityComponent>(100);
        var e = Bitecs.addEntity(w);
        var c = w.addComponent(EntityComponent, e);
        Assert.isFalse(c.entity.isValid()); // Stored as Int32 by default.
        Assert.isTrue(c.eid.isValid()); // Stored as Uint32.
        Assert.equals(4294967295, c.eid);
    }

    public function testArrayType() {
        var w = new World<ArrayComp>(100);
        var e = Bitecs.addEntity(w);
        var c = w.addComponent(ArrayComp, e);
        Assert.isTrue(c.arrFloat is js.lib.Float64Array);
        Assert.isTrue(c.arrInt is js.lib.Int16Array);
        Assert.isTrue(c.arrAbstract is js.lib.Int8Array);
        Assert.equals(10, c.arrFloat.length);
        Assert.equals(10 * 8, c.arrFloat.byteLength);
        Assert.equals(10, c.arrInt.length);
        Assert.equals(10 * 2, c.arrInt.byteLength);
        Assert.equals(10, c.arrAbstract.length);
        Assert.equals(10 * 1, c.arrAbstract.byteLength);
        for (i in 0...10) c.arrAbstract[i] = -i;
        Assert.equals(-45, c.arrAbstract.sum());
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
    public var foo(default, null):FooBar; // Test imports from different package.

    public function new(initVal:Int) { // Required init param.
        this.initVal = initVal;
    }

    public inline function simpleFunc() return customSet == null;

    public inline function customSetter(name:String) {
        this.customSet = 'hello $name'; // Need to use `this` so the macro correctly rewrites to private setter.
    }

}

class EntityComponent implements IComponent {

    public var entity:Entity = Entity.NONE;
    @:bitecs.type(eid) public var eid:Entity = Entity.NONE;

}

class ArrayComp implements IComponent {

    @:bitecs.length(10) @:bitecs.type(i16) public var arrInt:Array<Int>;
    @:bitecs.length(10) public var arrFloat:Array<Float>;
    @:bitecs.length(10) public var arrAbstract:ArrAbstract;

}

@:forward abstract ArrAbstract(js.lib.Int8Array) from js.lib.Int8Array {

    public inline function sum() {
        var total = 0;
        for (n in this) total += n;
        return total;
    }

    @:op([]) public function arrayRead(n:Int):Int;

    @:op([]) public function arrayWrite(n:Int, v:Int):Int;

}

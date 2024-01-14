package cases;

class TestNotQuery extends Test {

    public function testDirect() {
        final universe = Bitecs.createUniverse();
        final world = {};
        Bitecs.createWorld(universe, world);
        final compA = Bitecs.defineComponent(universe, { a: Bitecs.Types.f32 });
        final compB = Bitecs.defineComponent(universe, { b: Bitecs.Types.f32 });

        final queryA = Bitecs.defineQuery([compA]);
        final queryANotB = Bitecs.defineQuery([compA, Bitecs.Not(compB)]);

        for (i in 0...10) {
            var e = Bitecs.addEntity(world);
            Bitecs.addComponent(world, compA, e);
            if (i % 2 == 0) Bitecs.addComponent(world, compB, e);
        }
        Assert.equals(10, queryA(world).length);
        Assert.equals(5, queryANotB(world).length);
    }

    public function testMacro() {
        var w = new MyNotWorld();
        for (i in 0...10) {
            var e = Bitecs.addEntity(w);
            Bitecs.addComponent(w, w.compA, e);
            if (i % 2 == 0) Bitecs.addComponent(w, w.compB, e);
        }
        w.s.check();
    }

}

private class MyNotWorld extends World<CompA, CompB> {

    public var s:CheckNotQuerySystem;

    public function new() {
        super();
        s = new CheckNotQuerySystem(this);
    }

}

private class CheckNotQuerySystem {

    public var a:Query<CompA>;
    public var aNotB:Query<CompA, Not<CompB>>;

    final w:MyNotWorld;

    public function new(w:MyNotWorld) {
        this.w = w;
        a.init(w);
        aNotB.init(w);
    }

    public function check() {
        Assert.equals(10, a.getLength(w));
        Assert.equals(5, aNotB.getLength(w));
        // for (e => c in aNotB.on(w)) {
        //     trace(e);
        //     // c.compB;
        // }
    }

}

private class CompA implements IComponent {

    public var x:Float = -1;

}

private class CompB implements IComponent {

    public var i:Int = -1;

}

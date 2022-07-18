package cases;

import bitecs.*;

class TestQueryMacro extends Test {

    public function testSimple() {
        var w = new MyWorld();
        var entities = [for (i in 0...5) Bitecs.addEntity(w)];
        w.addComponent(CompA, entities[0]);
        w.addComponent([CompA, CompB], entities[1]);
        w.addComponent(CompB, entities[2]);
        w.addComponent([CompB, CompC], entities[3]);
        w.addComponent(CompC, entities[4]);
        w.update();
        Assert.equals(1, w.getComponent(CompA, entities[0]).x);
        Assert.equals(2, w.getComponent(CompA, entities[1]).x);
        Assert.equals(entities[1], w.getComponent(CompB, entities[1]).i);
        Assert.equals(-1, w.getComponent(CompB, entities[2]).i);
        Assert.equals(-1, w.getComponent(CompB, entities[3]).i);
        Assert.equals('Entity ' + entities[3], w.getComponent(CompC, entities[3]).s);
        Assert.equals(null, w.getComponent(CompC, entities[4]).s);
    }

}

private class MyWorld extends World<CompA, CompB, CompC> {

    var s:MySystem;

    public function new() {
        super();
        s = new MySystem(this);
    }

    public function update() {
        s.run();
    }

}

private class MySystem {

    var a:Query<CompA>;
    var ab:Query<CompA, CompB>;
    var bc:Query<CompB, CompC>;
    final w:MyWorld;

    public function new(w:MyWorld) {
        this.w = w;
        a.init(w); // Same as `a = new Query<CompA>(w)`, just less typing.
        ab.init(w);
        bc.init(w);
    }

    public function run() {
        for (e in a.on(w)) e.compA.x = 1;
        for (id => e in ab.on(w)) {
            e.compA.x = 2;
            e.compB.i = id;
        }
        for (id => e in bc.on(w)) e.compC.s = 'Entity $id';
    }

}

private class CompA {

    public var x:Float = -1;

}

private class CompB {

    public var i:Int = -1;

}

private class CompC {

    public var s:String;

}

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
        Assert.equals(1., w.getComponent(CompA, entities[0]).x);
        Assert.equals(2., w.getComponent(CompA, entities[1]).x);
        Assert.equals(cast entities[1], w.getComponent(CompB, entities[1]).i);
        Assert.equals(-1, w.getComponent(CompB, entities[2]).i);
        Assert.equals(-1, w.getComponent(CompB, entities[3]).i);
        Assert.equals('Entity ' + entities[3], w.getComponent(CompC, entities[3]).s);
        Assert.equals(null, w.getComponent(CompC, entities[4]).s);
    }

    public function testEnterExit() {
        var w = new MyWorld();
        var entities = [for (_ in 0...5) Bitecs.addEntity(w)];
        var group1 = entities.slice(0, 3);
        var group2 = entities.slice(3);
        for (e in entities) w.addComponent(CompA, e);
        function getResult() return {
            enteredA: [for (e in w.s.a.enteredQuery()(w)) e],
            enteredB: [for (e in w.s.ab.enteredQuery()(w)) e],
            enteredC: [for (e in w.s.bc.enteredQuery()(w)) e],
            exitedA: [for (e in w.s.a.exitedQuery()(w)) e],
            exitedB: [for (e in w.s.ab.exitedQuery()(w)) e],
            exitedC: [for (e in w.s.bc.exitedQuery()(w)) e],
        }
        var res = getResult();
        Assert.same(entities, res.enteredA);
        Assert.same([], res.enteredB);
        Assert.same([], res.enteredC);
        Assert.same([], res.exitedA);
        Assert.same([], res.exitedB);
        Assert.same([], res.exitedC);
        for (e in entities) w.addComponent(CompB, e);
        var res = getResult();
        Assert.same([], res.enteredA);
        Assert.same(entities, res.enteredB);
        Assert.same([], res.enteredC);
        Assert.same([], res.exitedA);
        Assert.same([], res.exitedB);
        Assert.same([], res.exitedC);
        for (e in entities) w.addComponent(CompC, e);
        var res = getResult();
        Assert.same([], res.enteredA);
        Assert.same([], res.enteredB);
        Assert.same(entities, res.enteredC);
        Assert.same([], res.exitedA);
        Assert.same([], res.exitedB);
        Assert.same([], res.exitedC);
        for (e in group1) w.removeComponent(CompA, e);
        var res = getResult();
        Assert.same([], res.enteredA);
        Assert.same([], res.enteredB);
        Assert.same([], res.enteredC);
        Assert.same(group1, res.exitedA);
        Assert.same(group1, res.exitedB);
        Assert.same([], res.exitedC);
        for (e in group2) w.removeComponent([CompA, CompC], e);
        var res = getResult();
        Assert.same([], res.enteredA);
        Assert.same([], res.enteredB);
        Assert.same([], res.enteredC);
        Assert.same(group2, res.exitedA);
        Assert.same(group2, res.exitedB);
        Assert.same(group2, res.exitedC);
    }

    public function testSort() {
        var w = new World<CompB>();
        for (i in 0...5) {
            var eid = Bitecs.addEntity(w);
            w.addComponent(CompB, eid).i = i;
        }
        var q = new Query<CompB>(w);
        var i = 0;
        var iter = q.on(w).iterator();
        for (e in iter.sort(a.compB.i - b.compB.i)) Assert.equals(i++, e.compB.i);
        i = 4;
        iter.reset();
        for (e in iter.sort(b.compB.i - a.compB.i)) Assert.equals(i--, e.compB.i);
    }

    public function testFirst() {
        var w = new World<CompA, CompB>();
        for (i in 0...5) {
            var eid = Bitecs.addEntity(w);
            if (i == 3) w.addComponent(CompB, eid);
            else w.addComponent(CompA, eid);
        }
        var qA = new Query<CompA>(w);
        var qB = new Query<CompB>(w);
        var qAB = new Query<CompA, CompB>(w);
        var n = 0;
        for (e in qA.first(w)) Assert.equals(0, n++);
        for (eid => e in qB.first(w)) Assert.isFalse(w.hasComponent(CompA, eid));
        for (e in qAB.first(w)) Assert.fail();
    }

    public function testQueryEntityOf() {
        var w = new World<CompA, CompB>();
        var q = new Query<EntityAB>(w);
        var eid = Bitecs.addEntity(w);
        w.addComponent([CompA, CompB], eid);
        Assert.same([eid], q.entities(w));
    }

}

private class MyWorld extends World<CompA, CompB, CompC> {

    public var s:MySystem;

    public function new() {
        super();
        s = new MySystem(this);
    }

    public function update() {
        s.run();
    }

}

private class MySystem {

    public var a:Query<CompA>;
    public var ab:Query<CompA, CompB>;
    public var bc:Query<CompB, CompC>;

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

private class CompA implements IComponent {

    public var x:Float = -1;

}

private class CompB implements IComponent {

    public var i:Int = -1;

}

private class CompC implements IComponent {

    public var s:String;

}

typedef EntityAB = EntityOf<CompA, CompB>;

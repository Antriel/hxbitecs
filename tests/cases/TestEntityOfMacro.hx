package cases;

import bitecs.*;

class TestEntityOfMacro extends Test {

    final w = new World<MyCompA, MyCompB>();

    public function testSimple():Void {
        final q = new MyQuery(w);
        final e = Bitecs.addEntity(w);
        w.addComponent([MyCompA, MyCompB], e);
        for (e in q.on(w)) {
            e.myCompA.x++;
            e.myCompB.y++;
            call(e);
            callOfQuery(e);
        }
    }

    inline function call(e:EntityOf<MyCompA>):Void {
        Assert.equals(1, e.myCompA.x);
    }

    inline function callOfQuery(e:EntityOf<MyQuery>):Void {
        Assert.equals(1, e.myCompA.x);
        Assert.equals(1, e.myCompB.y);
    }

}

typedef MyQuery = Query<MyCompA, MyCompB>;

private class MyCompA implements IComponent {

    var x:Int = 0;

}

private class MyCompB implements IComponent {

    var y:Int = 0;

}

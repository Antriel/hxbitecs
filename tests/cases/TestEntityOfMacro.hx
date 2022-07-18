package cases;

import bitecs.*;

class TestEntityOfMacro extends Test {

    final w = new World<MyCompA, MyCompB>();

    public function testSimple():Void {
        final q = new Query<MyCompA, MyCompB>(w);
        final e = Bitecs.addEntity(w);
        w.addComponent([MyCompA, MyCompB], e);
        for (e in q.on(w)) {
            e.myCompA.x++;
            e.myCompB.y++;
            call(e);
        }
    }

    inline function call(e:EntityOf<MyCompA>):Void {
        Assert.equals(1, e.myCompA.x);
    }

}

private class MyCompA {

    var x:Int = 0;

}

private class MyCompB {

    var y:Int = 0;

}

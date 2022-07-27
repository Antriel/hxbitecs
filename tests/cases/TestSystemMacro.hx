package cases;

import bitecs.*;

class TestSystemMacro extends Test {

    public function testSimple() {
        var s = new MySystem(new MyWorld());
        Assert.notNull(s.query);
        @:privateAccess Assert.notNull(s.world);
    }

}

private class MySystem implements ISystem<MyWorld> {

    @:bitecs.query public final query:Query<MyComp>;

}

private class MyWorld extends World<MyComp> { }

private class MyComp implements IComponent { }

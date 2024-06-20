package cases;

import bitecs.*;
import bitecs.World;

class TestSystemMacro extends Test {

    public function testSimple() {
        var s = new MySystem(new MyWorld());
        Assert.notNull(s.query);
        @:privateAccess Assert.notNull(s.world);
    }

    public function testWorldOf() {
        var w:WorldOf<MyComp> = new MyWorld();
        var s = new WorldOfSystem(w);
        Assert.notNull(s.query);
        @:privateAccess Assert.notNull(s.world);
        @:privateAccess for (e in s.query.on(s.world)) {
            e.myComp;
            s.world.addEntity(); // Testing static extensions.
        }
    }

}

private class MySystem implements ISystem<MyWorld> {

    @:bitecs.query public final query:Query<MyComp>;

}

private class WorldOfSystem implements ISystem<WorldOf<MyComp>> {

    @:bitecs.query public final query:Query<MyComp>;

}


private class MyWorld extends World<MyComp> { }

private class MyComp implements IComponent { }

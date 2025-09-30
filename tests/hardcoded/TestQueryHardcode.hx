package hardcoded;

import hxbitecs.QueryIterator;

class TestQueryHardcode extends Test {

    public function testQuery() {
        final position = { x: [], y: [] };
        final velocity = { x: [], y: [] };
        final world = Bitecs.createWorld({ pos: position, vel: velocity });

        for (_ in 0...10) {
            final entity = Bitecs.addEntity(world);
            Bitecs.addComponent(world, entity, position);
            Bitecs.addComponent(world, entity, velocity);
            position.x[entity] = 0.;
            position.y[entity] = 0.;
            velocity.x[entity] = 1.;
            velocity.y[entity] = 1. + entity;
        }

        var posVelQuery = new PosVelQuery(world);

        for (e in posVelQuery) {
            e.pos.x += e.vel.x;
            e.pos.y += e.vel.y;
        }
        for (e in Bitecs.query(world, [position, velocity]).asType1) {
            Assert.equals(1., position.x[e]);
            Assert.equals(1. + e, position.y[e]);
        }
    }

}

abstract PosVelQuery(bitecs.core.query.Query) {

    public function new(world:{pos:{x:Array<Float>, y:Array<Float>}, vel:{x:Array<Float>, y:Array<Float>}}) {
        this = Bitecs.registerQuery(world, [world.pos, world.vel]);
    }

    public inline function iterator() return new QueryIterator<PosVelWrapper>(this);

}

class PosVelWrapper {

    public final eid:Int;
    public final pos:XYSoAWrapper;
    public final vel:XYSoAWrapper;

    public inline function new(eid:Int, allComponents:Array<Dynamic>) {
        this.eid = eid;
        this.pos = new XYSoAWrapper({ store: allComponents[0], eid: eid });
        this.vel = new XYSoAWrapper({ store: allComponents[1], eid: eid });
    }

}

abstract XYSoAWrapper({store:{x:Array<Float>, y:Array<Float>}, eid:Int}) {

    public inline function new(v) this = v;

    public var x(get, set):Float;
    public var y(get, set):Float;

    public inline function get_x() return this.store.x[this.eid];

    public inline function get_y() return this.store.y[this.eid];

    public inline function set_x(v:Float) return this.store.x[this.eid] = v;

    public inline function set_y(v:Float) return this.store.y[this.eid] = v;

}

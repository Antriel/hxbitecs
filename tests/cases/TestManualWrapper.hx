package cases;

class TestManualWrapper extends Test {

    public function testSimple() {
        var world = new World();
        var movement = new MovementSystem(world);
        function addEntity(x:Float) {
            var e = Bitecs.addEntity(world);
            Bitecs.addComponent(world, world.position, e);
            Bitecs.addComponent(world, world.velocity, e);
            world.position.x[e] = x;
            world.velocity.x[e] = 1;
            return e;
        }
        var entities = [for (i in 0...5) addEntity(i)];
        var processed = movement.update(1);
        Assert.same(entities, processed);
        for (i => eid in processed) Assert.equals(i + 1, world.position.x[eid]);
    }

}

final Vec2Def = { x: Bitecs.Types.f64, y: Bitecs.Types.f64 };

private class World {

    public final velocity:{x:Array<Float>, y:Array<Float>} = Bitecs.defineComponent(Vec2Def);
    public final position:{x:Array<Float>, y:Array<Float>} = Bitecs.defineComponent(Vec2Def);

    public function new() {
        Bitecs.createWorld(this, 100);
    }

}

private class MovementSystem {

    final world:World;
    final query:PosVelQuery;

    public function new(w:World) {
        world = w;
        query = Bitecs.defineQuery([w.position, w.velocity]);
    }

    public function update(dt:Float) {
        var processed = [];
        for (eid => node in query.on(world)) {
            processed.push(eid);
            node.position.x += node.velocity.x * dt;
            node.position.y += node.velocity.y * dt;
        }
        return processed;
    }

}

private abstract PosVelQuery(bitecs.Query.QueryType<Dynamic>) from bitecs.Query.QueryType<Dynamic> {

    public inline function iterator(world:{final position:{x:Array<Float>, y:Array<Float>}; final velocity:{x:Array<Float>, y:Array<Float>};}) {
        return new PosVelQueryIterator(this(world), world.position, world.velocity);
    }

    public inline function keyValueIterator(world) return new EntityValueIterator(iterator(world));

    public inline function on(world:{final position:{x:Array<Float>, y:Array<Float>}; final velocity:{x:Array<Float>, y:Array<Float>};})
        return new PosVelQueryHelper(world, (this:PosVelQuery));

}

private abstract PosVelQueryHelper({w:{final position:{x:Array<Float>, y:Array<Float>}; final velocity:{x:Array<Float>, y:Array<Float>};}, q:PosVelQuery}) {

    public inline function new(w, q) this = { w: w, q: q };

    public inline function iterator() return this.q.iterator(this.w);

    public inline function keyValueIterator() return this.q.keyValueIterator(this.w);

}

private class EntityValueIterator<V, T:Iterator<V> & {eid:Entity}> {

    final iter:T;

    public inline function new(iter:T) {
        this.iter = iter;
    }

    public inline function hasNext() return iter.hasNext();

    public inline function next() {
        final value = iter.next();
        return {
            key: iter.eid,
            value: value
        };
    }

}

private class PosVelQueryIterator {

    final ents:Array<bitecs.Entity>;
    final length:Int;
    final position:{x:Array<Float>, y:Array<Float>};
    final velocity:{x:Array<Float>, y:Array<Float>};

    public var eid:Entity;

    var i = 0;

    public inline function new(ents:Array<bitecs.Entity>, position, velocity) {
        this.ents = ents;
        this.position = position;
        this.velocity = velocity;
        this.length = ents.length;
    }

    public inline function hasNext() return i < length;

    public inline function next() {
        eid = ents[i++];
        return {
            position: new Vec2Wrapper(eid, position),
            velocity: new Vec2Wrapper(eid, velocity),
        }
    }

}

private abstract Vec2Wrapper({final ent:bitecs.Entity; final store:{x:Array<Float>, y:Array<Float>};}) {

    public inline function new(ent:bitecs.Entity, store:{x:Array<Float>, y:Array<Float>}) {
        this = { ent: ent, store: store };
    }

    public var x(get, set):Float;

    inline function get_x() return this.store.x[this.ent];

    inline function set_x(v) return this.store.x[this.ent] = v;

    public var y(get, set):Float;

    inline function get_y() return this.store.y[this.ent];

    inline function set_y(v) return this.store.y[this.ent] = v;

}

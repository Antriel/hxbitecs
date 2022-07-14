package bitecs;

@:genericBuild(bitecs.Query.build()) class Query<Rest> { }

typedef QueryType<W> = (world:W, ?clearDiff:Bool) -> Array<Entity>;

@:generic class EntityValueIterator<V, T:Iterator<V> & {eid:Entity}> {

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

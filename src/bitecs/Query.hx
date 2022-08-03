package bitecs;

@:genericBuild(bitecs.Query.build()) class Query<Rest> { }

typedef QueryType<W> = (world:W, ?clearDiff:Bool) -> Array<Entity>;

@:generic class EntityValueIterator<V, T:Iterator<V> & {eid:Entity, length:Int}> {

    final iter:T;

    public var length(get, never):Int;

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

    private inline function get_length() return iter.length;

}

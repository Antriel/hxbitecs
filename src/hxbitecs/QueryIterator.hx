package hxbitecs;

import bitecs.core.query.Query;

@:generic class QueryIterator<T:haxe.Constraints.Constructible<Int->Query->Void>> {
    var query:Query;
    var i:Int = 0;

    public inline function new(query:Query) {
        this.query = query;
    }

    public inline function hasNext():Bool {
        return i < query.dense.asType0.length;
    }

    public inline function next() {
        var eid = query.dense.asType1[i];
        i++;
        return new T(eid, query);
    }
}

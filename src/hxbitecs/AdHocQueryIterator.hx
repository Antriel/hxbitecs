package hxbitecs;

import bitecs.core.entity.EntityId;
import bitecs.core.query.QueryResult;

/**
 * Iterator for ad-hoc queries that creates entity wrappers on-demand.
 * Similar to QueryIterator but works with QueryResult instead of persistent Query objects.
 */
@:generic class AdHocQueryIterator<T:haxe.Constraints.Constructible<Int->Array<Dynamic>->Void>> {
    final entities:haxe.ds.ReadOnlyArray<Int>;
    final components:Array<Dynamic>;
    var i:Int = 0;

    public inline function new(queryResult:QueryResult, components:Array<Dynamic>) {
        this.entities = queryResult.asType1;
        this.components = components;
    }

    public inline function hasNext():Bool {
        return i < entities.length;
    }

    public inline function next():T {
        var eid = entities[i];
        i++;
        return new T(eid, components);
    }

}

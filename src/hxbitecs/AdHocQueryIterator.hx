package hxbitecs;

import bitecs.core.entity.EntityId;
import bitecs.core.query.QueryResult;

/**
 * Iterator for ad-hoc queries that creates entity wrappers on-demand.
 * Similar to QueryIterator but works with QueryResult instead of persistent Query objects.
 */
@:generic class AdHocQueryIterator<T:haxe.Constraints.Constructible<Int->Dynamic->Void>> {
    final entities:haxe.ds.ReadOnlyArray<Int>;
    final components:Array<Dynamic>;
    final mockQuery:Dynamic;
    var i:Int = 0;

    public inline function new(queryResult:QueryResult, components:Array<Dynamic>) {
        this.entities = queryResult.asType1;
        this.components = components;

        // Create a mock query object that provides the allComponents interface
        // that entity wrappers expect
        this.mockQuery = {
            allComponents: components
        };
    }

    public inline function hasNext():Bool {
        return i < entities.length;
    }

    public inline function next():T {
        var eid = entities[i];
        i++;
        return new T(eid, mockQuery);
    }

}

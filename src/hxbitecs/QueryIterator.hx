package hxbitecs;

/**
 * Generic iterator for both persistent queries and ad-hoc queries.
 * Creates entity wrappers on-demand from entity IDs and component stores.
 */
@:generic class QueryIterator<T:haxe.Constraints.Constructible<Int->Array<Dynamic>->Void>> {
    final entities:haxe.ds.ReadOnlyArray<Int>;
    final length:Int;
    final components:Array<Dynamic>;
    var i:Int = 0;

    public inline function new(entities:haxe.ds.ReadOnlyArray<Int>, components:Array<Dynamic>) {
        this.entities = entities;
        this.length = entities.length;
        this.components = components;
    }

    public inline function hasNext():Bool {
        return i < length;
    }

    public inline function next():T {
        var eid = entities[i];
        i++;
        return new T(eid, components);
    }
}

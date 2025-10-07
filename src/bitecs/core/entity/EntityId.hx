package bitecs.core.entity;

abstract EntityId(Int) from Int to Int {

    public static inline var NONE:EntityId = cast -1;

    public inline function isValid():Bool return this >= 0;

}

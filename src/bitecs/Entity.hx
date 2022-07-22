package bitecs;

abstract Entity(Int) to Int {

    public static inline var NONE:Entity = cast -1;

    public inline function isValid():Bool return this >= 0;

}

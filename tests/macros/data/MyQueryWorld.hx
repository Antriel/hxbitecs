package macros.data;

@:publicFields class MyQueryWorld {

    function new() { }

    var pos = { x: new Array<Float>(), y: new Array<Float>() };
    var vel = { x: new Array<Float>(), y: new Array<Float>() };
    var health = new Array<{hp:Int}>();
    var isPoisoned = {};

}

// Typedef for testing Query.on() method and Query.entity() static method
typedef MovingQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, vel]>;
typedef ComplexQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, Or(vel, health)]>;
typedef TagQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, isPoisoned]>;
typedef HealthQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, health]>;
typedef PosNotVelQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, Not(vel)]>;
typedef PosNoneVelHealthQuery = hxbitecs.HxQuery<MyQueryWorld, [pos, None(vel, health)]>;

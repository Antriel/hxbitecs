package bitecs.core.utils.observer;

typedef Observer = (entity:Float, args:haxe.extern.Rest<Dynamic>) -> ts.AnyOf2<ts.Undefined, Dynamic>;

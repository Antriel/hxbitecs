package bitecs.core.utils.sparseset;

typedef SparseSet = {
	dynamic function add(val:Float):Void;
	dynamic function remove(val:Float):Void;
	dynamic function has(val:Float):Bool;
	var sparse : Array<Float>;
	var dense : ts.AnyOf2<js.lib.Uint32Array, Array<Float>>;
	dynamic function reset():Void;
	dynamic function sort(?compareFn:(a:Float, b:Float) -> Float):Void;
};

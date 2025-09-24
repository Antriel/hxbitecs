package bitecs.core.query;

typedef QueryResult = ts.AnyOf2<{
	/**
		The size in bytes of each element in the array.
	**/
	var BYTES_PER_ELEMENT : Float;
	/**
		The ArrayBuffer instance referenced by the array.
	**/
	var buffer : js.lib.ArrayBuffer;
	/**
		The length in bytes of the array.
	**/
	var byteLength : Float;
	/**
		The offset in bytes of the array.
	**/
	var byteOffset : Float;
	/**
		Returns the this object after copying a section of the array identified by start and end
		to the same array starting at position target
	**/
	dynamic function copyWithin(target:Float, start:Float, ?end:Float):js.lib.Uint32Array;
	/**
		Determines whether all the members of an array satisfy the specified test.
	**/
	dynamic function every(callbackfn:(value:Float, index:Float, array:js.lib.Uint32Array) -> Any, ?thisArg:Dynamic):Bool;
	/**
		Returns the this object after filling the section identified by start and end with value
	**/
	dynamic function fill(value:Float, ?start:Float, ?end:Float):js.lib.Uint32Array;
	/**
		Returns the elements of an array that meet the condition specified in a callback function.
	**/
	dynamic function filter(callbackfn:(value:Float, index:Float, array:js.lib.Uint32Array) -> Dynamic, ?thisArg:Dynamic):js.lib.Uint32Array;
	/**
		Returns the value of the first element in the array where predicate is true, and undefined
		otherwise.
	**/
	dynamic function find(predicate:(value:Float, index:Float, obj:js.lib.Uint32Array) -> Bool, ?thisArg:Dynamic):Null<Float>;
	/**
		Returns the index of the first element in the array where predicate is true, and -1
		otherwise.
	**/
	dynamic function findIndex(predicate:(value:Float, index:Float, obj:js.lib.Uint32Array) -> Bool, ?thisArg:Dynamic):Float;
	/**
		Performs the specified action for each element in an array.
	**/
	dynamic function forEach(callbackfn:(value:Float, index:Float, array:js.lib.Uint32Array) -> Void, ?thisArg:Dynamic):Void;
	/**
		Returns the index of the first occurrence of a value in an array.
	**/
	dynamic function indexOf(searchElement:Float, ?fromIndex:Float):Float;
	/**
		Adds all the elements of an array separated by the specified separator string.
	**/
	dynamic function join(?separator:String):String;
	/**
		Returns the index of the last occurrence of a value in an array.
	**/
	dynamic function lastIndexOf(searchElement:Float, ?fromIndex:Float):Float;
	/**
		The length of the array.
	**/
	var length : Float;
	/**
		Calls a defined callback function on each element of an array, and returns an array that
		contains the results.
	**/
	dynamic function map(callbackfn:(value:Float, index:Float, array:js.lib.Uint32Array) -> Float, ?thisArg:Dynamic):js.lib.Uint32Array;
	/**
		Calls the specified callback function for all the elements in an array. The return value of
		the callback function is the accumulated result, and is provided as an argument in the next
		call to the callback function.
		
		Calls the specified callback function for all the elements in an array. The return value of
		the callback function is the accumulated result, and is provided as an argument in the next
		call to the callback function.
	**/
	@:overload(function(callbackfn:(previousValue:Float, currentValue:Float, currentIndex:Float, array:js.lib.Uint32Array) -> Float, initialValue:Float):Float { })
	@:overload(function<U>(callbackfn:(previousValue:U, currentValue:Float, currentIndex:Float, array:js.lib.Uint32Array) -> U, initialValue:U):U { })
	dynamic function reduce(callbackfn:(previousValue:Float, currentValue:Float, currentIndex:Float, array:js.lib.Uint32Array) -> Float):Float;
	/**
		Calls the specified callback function for all the elements in an array, in descending order.
		The return value of the callback function is the accumulated result, and is provided as an
		argument in the next call to the callback function.
		
		Calls the specified callback function for all the elements in an array, in descending order.
		The return value of the callback function is the accumulated result, and is provided as an
		argument in the next call to the callback function.
	**/
	@:overload(function(callbackfn:(previousValue:Float, currentValue:Float, currentIndex:Float, array:js.lib.Uint32Array) -> Float, initialValue:Float):Float { })
	@:overload(function<U>(callbackfn:(previousValue:U, currentValue:Float, currentIndex:Float, array:js.lib.Uint32Array) -> U, initialValue:U):U { })
	dynamic function reduceRight(callbackfn:(previousValue:Float, currentValue:Float, currentIndex:Float, array:js.lib.Uint32Array) -> Float):Float;
	/**
		Reverses the elements in an Array.
	**/
	dynamic function reverse():js.lib.Uint32Array;
	/**
		Sets a value or an array of values.
	**/
	dynamic function set(array:js.lib.ArrayLike<Float>, ?offset:Float):Void;
	/**
		Returns a section of an array.
	**/
	dynamic function slice(?start:Float, ?end:Float):js.lib.Uint32Array;
	/**
		Determines whether the specified callback function returns true for any element of an array.
	**/
	dynamic function some(callbackfn:(value:Float, index:Float, array:js.lib.Uint32Array) -> Any, ?thisArg:Dynamic):Bool;
	/**
		Sorts an array.
	**/
	dynamic function sort(?compareFn:(a:Float, b:Float) -> Float):js.lib.Uint32Array;
	/**
		Gets a new Uint32Array view of the ArrayBuffer store for this array, referencing the elements
		at begin, inclusive, up to end, exclusive.
	**/
	dynamic function subarray(?begin:Float, ?end:Float):js.lib.Uint32Array;
	/**
		Converts a number to a string by using the current locale.
	**/
	dynamic function toLocaleString():String;
	/**
		Returns a string representation of an array.
	**/
	dynamic function toString():String;
	/**
		Returns an array of key, value pairs for every entry in the array
	**/
	dynamic function entries():js.lib.IterableIterator<ts.Tuple2<Float, Float>>;
	/**
		Returns an list of keys in the array
	**/
	dynamic function keys():js.lib.IterableIterator<Float>;
	/**
		Returns an list of values in the array
	**/
	dynamic function values():js.lib.IterableIterator<Float>;
}, haxe.ds.ReadOnlyArray<Float>>;

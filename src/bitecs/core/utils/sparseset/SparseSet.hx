package bitecs.core.utils.sparseset;

import bitecs.core.entity.EntityId;

typedef SparseSet = {
    dynamic function add(val:EntityId):Void;
    dynamic function remove(val:EntityId):Void;
    dynamic function has(val:EntityId):Bool;
    var sparse:Array<EntityId>;
    var dense:ts.AnyOf2<js.lib.Uint32Array, Array<EntityId>>;
	dynamic function reset():Void;
    dynamic function sort(?compareFn:(a:EntityId, b:EntityId) -> EntityId):Void;
};

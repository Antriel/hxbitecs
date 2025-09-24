package bitecs.core.query;

typedef Query = bitecs.core.utils.sparseset.SparseSet & {
	var allComponents : Array<Dynamic>;
	var orComponents : Array<Dynamic>;
	var notComponents : Array<Dynamic>;
	var masks : Array<Float>;
	var orMasks : Array<Float>;
	var notMasks : Array<Float>;
	var hasMasks : Array<Float>;
	var generations : Array<Float>;
	var toRemove : bitecs.core.utils.sparseset.SparseSet;
	var addObservable : bitecs.core.utils.observer.Observable;
	var removeObservable : bitecs.core.utils.observer.Observable;
	var queues : haxe.DynamicAccess<Dynamic>;
};

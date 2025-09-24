package bitecs.core.utils;

@:jsRequire("bitecs/dist/core/utils/SparseSet") @valueModuleOnly extern class SparseSet {
	static function createSparseSet():bitecs.core.utils.sparseset.SparseSet;
	static function createUint32SparseSet(?initialCapacity:Float):bitecs.core.utils.sparseset.SparseSet;
}

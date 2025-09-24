package bitecs.core;

@:jsRequire("bitecs/dist/core/Hierarchy") @valueModuleOnly extern class Hierarchy {
	static function ensureDepthTracking(world:{ }, relation:Dynamic):Void;
	static function calculateEntityDepth(world:{ }, relation:Dynamic, entity:Float, ?visited:js.lib.Set<Float>):Float;
	static function markChildrenDirty(world:{ }, relation:Dynamic, parent:Float, dirty:bitecs.core.utils.sparseset.SparseSet, ?visited:bitecs.core.utils.sparseset.SparseSet):Void;
	static function updateHierarchyDepth(world:{ }, relation:Dynamic, entity:Float, ?parent:Float, ?updating:js.lib.Set<Float>):Void;
	static function invalidateHierarchyDepth(world:{ }, relation:Dynamic, entity:Float):Void;
	static function flushDirtyDepths(world:{ }, relation:Dynamic):Void;
	static function queryHierarchy(world:{ }, relation:Dynamic, components:Array<Dynamic>, ?options:{ @:optional var buffered : Bool; }):bitecs.core.query.QueryResult;
	static function queryHierarchyDepth(world:{ }, relation:Dynamic, depth:Float, ?options:{ @:optional var buffered : Bool; }):bitecs.core.query.QueryResult;
	static function getHierarchyDepth(world:{ }, entity:Float, relation:Dynamic):Float;
	static function getMaxHierarchyDepth(world:{ }, relation:Dynamic):Float;
}

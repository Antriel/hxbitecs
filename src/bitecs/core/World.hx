package bitecs.core;

@:jsRequire("bitecs/dist/core/World") @valueModuleOnly extern class World {
	static function createWorld<T>(args:haxe.extern.Rest<ts.AnyOf2<bitecs.core.entityindex.EntityIndex, T>>):{ };
	@:native("$internal")
	static final DollarInternal : js.lib.Symbol;
	static function resetWorld(world:{ }):{ };
	static function deleteWorld(world:{ }):Void;
	static function getWorldComponents(world:{ }):Array<String>;
	static function getAllEntities(world:{ }):haxe.ds.ReadOnlyArray<Float>;
}

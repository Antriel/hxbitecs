package bitecs.core;

@:jsRequire("bitecs/dist/core/Entity") @valueModuleOnly extern class Entity {
	static final Prefab : { };
	static function addPrefab(world:{ }):Float;
	static function addEntity(world:{ }):Float;
	static function removeEntity(world:{ }, eid:Float):Void;
	static function getEntityComponents(world:{ }, eid:Float):Array<Dynamic>;
	static function entityExists(world:{ }, eid:Float):Bool;
}

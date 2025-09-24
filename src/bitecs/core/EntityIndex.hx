package bitecs.core;

@:jsRequire("bitecs/dist/core/EntityIndex") @valueModuleOnly extern class EntityIndex {
	static function getId(index:bitecs.core.entityindex.EntityIndex, id:Float):Float;
	static function getVersion(index:bitecs.core.entityindex.EntityIndex, id:Float):Float;
	static function incrementVersion(index:bitecs.core.entityindex.EntityIndex, id:Float):Float;
	static function withVersioning(?versionBits:Float):{
		var versioning : Bool;
		var versionBits : Float;
	};
	static function createEntityIndex(?options:ts.AnyOf3<() -> { var versioning : Bool; var versionBits : Float; }, (versionBits:Float) -> { var versioning : Bool; var versionBits : Float; }, { var versioning : Bool; var versionBits : Float; }>):bitecs.core.entityindex.EntityIndex;
	static function addEntityId(index:bitecs.core.entityindex.EntityIndex):Float;
	static function removeEntityId(index:bitecs.core.entityindex.EntityIndex, id:Float):Void;
	static function isEntityIdAlive(index:bitecs.core.entityindex.EntityIndex, id:Float):Bool;
}

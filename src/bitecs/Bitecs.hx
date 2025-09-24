package bitecs;

import haxe.extern.EitherType;
import bitecs.core.entity.EntityId;

@:jsRequire("bitecs") @valueModuleOnly extern class Bitecs {
	static function createWorld<T>(args:haxe.extern.Rest<ts.AnyOf2<bitecs.core.entityindex.EntityIndex, T>>):{ };
	static function resetWorld(world:{ }):{ };
	static function deleteWorld(world:{ }):Void;
	static function getWorldComponents(world:{ }):Array<String>;
	static function getAllEntities(world:{ }):haxe.ds.ReadOnlyArray<Float>;
	@:native("$internal")
	static final DollarInternal : js.lib.Symbol;
	static function addEntity(world:{ }):EntityId;
	static function removeEntity(world:{ }, eid:EntityId):Void;
	static function getEntityComponents(world:{ }, eid:EntityId):Array<Dynamic>;
	static function entityExists(world:{ }, eid:EntityId):Bool;
	static final Prefab : { };
	static function addPrefab(world:{ }):Float;
	static function createEntityIndex(?options:ts.AnyOf3<() -> { var versioning : Bool; var versionBits : Float; }, (versionBits:Float) -> { var versioning : Bool; var versionBits : Float; }, { var versioning : Bool; var versionBits : Float; }>):bitecs.core.entityindex.EntityIndex;
	static function getId(index:bitecs.core.entityindex.EntityIndex, id:Float):Float;
	static function getVersion(index:bitecs.core.entityindex.EntityIndex, id:Float):Float;
	static function withVersioning(?versionBits:Float):{
		var versioning : Bool;
		var versionBits : Float;
	};
	static function registerComponent(world:{ }, component:Dynamic):bitecs.core.component.ComponentData;
	static function registerComponents(world:{ }, components:Array<Dynamic>):Void;
	static function hasComponent(world:{ }, eid:Float, component:Dynamic):Bool;
	static function addComponent(world:{ }, eid:Float, componentOrSet:Dynamic):Bool;
	@:overload(function(world:{ }, eid:Float, components:haxe.extern.Rest<Dynamic>):Void { })
	static function addComponents(world:{ }, eid:Float, components:Array<Dynamic>):Void;
	static function setComponent(world:{ }, eid:Float, component:Dynamic, data:Dynamic):Void;
	static function removeComponent(world:{ }, eid:Float, components:haxe.extern.Rest<Dynamic>):Void;
	static function removeComponents(world:{ }, eid:Float, components:haxe.extern.Rest<Dynamic>):Void;
	static function getComponent(world:{ }, eid:Float, component:Dynamic):Dynamic;
	static function set<T>(component:T, data:Dynamic):{
		var component : T;
		var data : Dynamic;
	};
	static function commitRemovals(world:{ }):Void;
	static function removeQuery(world:{ }, terms:Array<Dynamic>):Void;
	static function registerQuery(world:{ }, terms:Array<Dynamic>, ?options:{ @:optional var buffered : Bool; }):bitecs.core.query.Query;
	static function query(world:{ }, terms:Array<Dynamic>, modifiers:haxe.extern.Rest<ts.AnyOf2<bitecs.core.query.QueryModifier, bitecs.core.query.QueryOptions>>):bitecs.core.query.QueryResult;
	static overload function observe(world:{ }, hook:{ }, callback:(eid:EntityId, args:Dynamic) -> Dynamic):() -> Void;
	static overload function observe(world:{ }, hook:{ }, callback:(eid:EntityId, args:Dynamic) -> Void):() -> Void;
	static overload function observe(world:{ }, hook:{ }, callback:(eid:EntityId) -> Dynamic):() -> Void;
	static function onAdd(terms:haxe.extern.Rest<Dynamic>):{ };
	static function onRemove(terms:haxe.extern.Rest<Dynamic>):{ };
	static function Or(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function And(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function Not(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function Any(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function All(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function None(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function onGet(terms:haxe.extern.Rest<Dynamic>):{ };
	static function onSet(terms:haxe.extern.Rest<Dynamic>):{ };
	static function Hierarchy(relation:Dynamic, ?depth:Float):bitecs.core.query.HierarchyTerm;
	static function Cascade(relation:Dynamic, ?depth:Float):bitecs.core.query.HierarchyTerm;
	static final asBuffer : bitecs.core.query.QueryModifier;
	static final isNested : bitecs.core.query.QueryModifier;
	static final noCommit : bitecs.core.query.QueryModifier;
	static function pipe<T, U, R>(functions_0:T, functions_1:U, functions_2:R):(args:haxe.extern.Rest<Any>) -> js.lib.ReturnType<R>;
	static function withAutoRemoveSubject<T>(relation:bitecs.core.relation.Relation<T>):bitecs.core.relation.Relation<T>;
	static function withOnTargetRemoved<T>(onRemove:bitecs.core.relation.OnTargetRemovedCallback):(relation:bitecs.core.relation.Relation<T>) -> bitecs.core.relation.Relation<T>;
	static function withStore<T>(createStore:(eid:Float) -> T):(relation:bitecs.core.relation.Relation<T>) -> bitecs.core.relation.Relation<T>;
	@:overload(function<T>(options:{ @:optional dynamic function store():T; @:optional var exclusive : Bool; @:optional var autoRemoveSubject : Bool; @:optional dynamic function onTargetRemoved(subject:Float, target:Float):Void; }):bitecs.core.relation.Relation<T> { })
	static function createRelation<T>(modifiers:haxe.extern.Rest<(relation:bitecs.core.relation.Relation<T>) -> bitecs.core.relation.Relation<T>>):bitecs.core.relation.Relation<T>;
	static function getRelationTargets(world:Dynamic, eid:Float, relation:bitecs.core.relation.Relation<Dynamic>):Array<Float>;
	static function Wildcard(target:bitecs.core.relation.RelationTarget):Dynamic;
	static function IsA(target:bitecs.core.relation.RelationTarget):Dynamic;
	static function Pair<T>(relation:bitecs.core.relation.Relation<T>, target:bitecs.core.relation.RelationTarget):T;
	static function isRelation(component:Dynamic):Bool;
	static function isWildcard(relation:Dynamic):Bool;
	static function getHierarchyDepth(world:{ }, entity:Float, relation:Dynamic):Float;
	static function getMaxHierarchyDepth(world:{ }, relation:Dynamic):Float;
}

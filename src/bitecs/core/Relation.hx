package bitecs.core;

@:jsRequire("bitecs/dist/core/Relation") @valueModuleOnly extern class Relation {
	@:overload(function<T>(options:{ @:optional dynamic function store():T; @:optional var exclusive : Bool; @:optional var autoRemoveSubject : Bool; @:optional dynamic function onTargetRemoved(subject:Float, target:Float):Void; }):bitecs.core.relation.Relation<T> { })
	static function createRelation<T>(modifiers:haxe.extern.Rest<(relation:bitecs.core.relation.Relation<T>) -> bitecs.core.relation.Relation<T>>):bitecs.core.relation.Relation<T>;
	static function createWildcardRelation<T>():bitecs.core.relation.Relation<T>;
	static function getWildcard():bitecs.core.relation.Relation<Dynamic>;
	static function createIsARelation<T>():bitecs.core.relation.Relation<T>;
	static function getIsA():bitecs.core.relation.Relation<Dynamic>;
	static function isWildcard(relation:Dynamic):Bool;
	static function isRelation(component:Dynamic):Bool;
	@:native("$relation")
	static final DollarRelation : js.lib.Symbol;
	@:native("$pairTarget")
	static final DollarPairTarget : js.lib.Symbol;
	@:native("$isPairComponent")
	static final DollarIsPairComponent : js.lib.Symbol;
	@:native("$relationData")
	static final DollarRelationData : js.lib.Symbol;
	static function withStore<T>(createStore:(eid:Float) -> T):(relation:bitecs.core.relation.Relation<T>) -> bitecs.core.relation.Relation<T>;
	static function makeExclusive<T>(relation:bitecs.core.relation.Relation<T>):bitecs.core.relation.Relation<T>;
	static function withAutoRemoveSubject<T>(relation:bitecs.core.relation.Relation<T>):bitecs.core.relation.Relation<T>;
	static function withOnTargetRemoved<T>(onRemove:bitecs.core.relation.OnTargetRemovedCallback):(relation:bitecs.core.relation.Relation<T>) -> bitecs.core.relation.Relation<T>;
	static function Pair<T>(relation:bitecs.core.relation.Relation<T>, target:bitecs.core.relation.RelationTarget):T;
	static function getRelationTargets(world:Dynamic, eid:Float, relation:bitecs.core.relation.Relation<Dynamic>):Array<Float>;
	@:native("$wildcard")
	static final DollarWildcard : js.lib.Symbol;
	static function Wildcard(target:bitecs.core.relation.RelationTarget):Dynamic;
	static function IsA(target:bitecs.core.relation.RelationTarget):Dynamic;
}

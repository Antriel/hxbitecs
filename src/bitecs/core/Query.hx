package bitecs.core;

@:jsRequire("bitecs/dist/core/Query") @valueModuleOnly extern class Query {
	static function observe(world:{ }, hook:{ }, callback:(eid:Float, args:haxe.extern.Rest<Dynamic>) -> Dynamic):() -> Void;
	static function queryInternal(world:{ }, terms:Array<Dynamic>, ?options:{ @:optional var buffered : Bool; }):bitecs.core.query.QueryResult;
	static function query(world:{ }, terms:Array<Dynamic>, modifiers:haxe.extern.Rest<ts.AnyOf2<bitecs.core.query.QueryModifier, bitecs.core.query.QueryOptions>>):bitecs.core.query.QueryResult;
	static function queryCheckEntity(world:{ }, query:bitecs.core.query.Query, eid:Float):Bool;
	@:native("$opType")
	static final DollarOpType : js.lib.Symbol;
	@:native("$opTerms")
	static final DollarOpTerms : js.lib.Symbol;
	static function Or(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function And(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function Not(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function Any(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function All(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	static function None(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
	@:native("$hierarchyType")
	static final DollarHierarchyType : js.lib.Symbol;
	@:native("$hierarchyRel")
	static final DollarHierarchyRel : js.lib.Symbol;
	@:native("$hierarchyDepth")
	static final DollarHierarchyDepth : js.lib.Symbol;
	static function Hierarchy(relation:Dynamic, ?depth:Float):bitecs.core.query.HierarchyTerm;
	static function Cascade(relation:Dynamic, ?depth:Float):bitecs.core.query.HierarchyTerm;
	@:native("$modifierType")
	static final DollarModifierType : js.lib.Symbol;
	static final asBuffer : bitecs.core.query.QueryModifier;
	static final isNested : bitecs.core.query.QueryModifier;
	static final noCommit : bitecs.core.query.QueryModifier;
	static function onAdd(terms:haxe.extern.Rest<Dynamic>):{ };
	static function onRemove(terms:haxe.extern.Rest<Dynamic>):{ };
	static function onSet(terms:haxe.extern.Rest<Dynamic>):{ };
	static function onGet(terms:haxe.extern.Rest<Dynamic>):{ };
	static function queryHash(world:{ }, terms:Array<Dynamic>):String;
	static function registerQuery(world:{ }, terms:Array<Dynamic>, ?options:{ @:optional var buffered : Bool; }):bitecs.core.query.Query;
	static function queryCheckComponent(query:bitecs.core.query.Query, c:bitecs.core.component.ComponentData):Bool;
	static function queryAddEntity(query:bitecs.core.query.Query, eid:Float):Void;
	static function commitRemovals(world:{ }):Void;
	static function queryRemoveEntity(world:{ }, query:bitecs.core.query.Query, eid:Float):Void;
	static function removeQuery(world:{ }, terms:Array<Dynamic>):Void;
}

package bitecs;

import haxe.extern.EitherType;
import bitecs.core.entity.EntityId;

@:jsRequire("bitecs") @valueModuleOnly extern class Bitecs {

    static overload function createWorld():{};
    static overload function createWorld<T>(ctx:T):T;
    static overload function createWorld<T>(ctx:T, index:bitecs.core.entityindex.EntityIndex):T;
    static overload function createWorld(index:bitecs.core.entityindex.EntityIndex):{};
    static overload function createWorld<T>(index:bitecs.core.entityindex.EntityIndex, ctx:T):T;
    static function resetWorld(world:{}):{};
    static function deleteWorld(world:{}):Void;
    static function getWorldComponents(world:{}):Array<String>;
    static function getAllEntities(world:{}):haxe.ds.ReadOnlyArray<EntityId>;
    @:native("$internal")
    static final DollarInternal:js.lib.Symbol;
    static function addEntity(world:{}):EntityId;
    static function removeEntity(world:{}, eid:EntityId):Void;
    static function getEntityComponents(world:{}, eid:EntityId):Array<Dynamic>;
    static function entityExists(world:{}, eid:EntityId):Bool;
    static final Prefab:{};
    static function addPrefab(world:{}):EntityId;
    static function createEntityIndex(?options:ts.AnyOf3<() -> {
        var versioning:Bool;
        var versionBits:Int;
    }, (versionBits:Int) -> {
        var versioning:Bool;
        var versionBits:Int;
    }, {var versioning:Bool; var versionBits:Int;}>):bitecs.core.entityindex.EntityIndex;
    static function getId(index:bitecs.core.entityindex.EntityIndex, id:Int):EntityId;
    static function getVersion(index:bitecs.core.entityindex.EntityIndex, id:Int):Int;
    static function withVersioning(?versionBits:Int):{
        var versioning:Bool;
        var versionBits:Int;
    };
    static function registerComponent(world:{}, component:Dynamic):bitecs.core.component.ComponentData;
    static function registerComponents(world:{}, components:Array<Dynamic>):Void;
    static function hasComponent(world:{}, eid:EntityId, component:Dynamic):Bool;
    static function addComponent(world:{}, eid:EntityId, componentOrSet:Dynamic):Bool;
    @:overload(function(world:{}, eid:EntityId, components:haxe.extern.Rest<Dynamic>):Void { })
    static function addComponents(world:{}, eid:EntityId, components:Array<Dynamic>):Void;
    static function setComponent(world:{}, eid:EntityId, component:Dynamic, data:Dynamic):Void;
    static function removeComponent(world:{}, eid:EntityId, components:haxe.extern.Rest<Dynamic>):Void;
    static function removeComponents(world:{}, eid:EntityId, components:haxe.extern.Rest<Dynamic>):Void;
    static function getComponent(world:{}, eid:EntityId, component:Dynamic):Dynamic;
    static function set<T>(component:T, data:Dynamic):{
        var component:T;
        var data:Dynamic;
    };
    static function commitRemovals(world:{}):Void;
    static function removeQuery(world:{}, terms:Array<Dynamic>):Void;
    static function registerQuery(world:{}, terms:Array<Dynamic>,
        ?options:{@:optional var buffered:Bool;}):bitecs.core.query.Query;
    static function query(world:{}, terms:Array<Dynamic>,
        modifiers:haxe.extern.Rest<ts.AnyOf2<bitecs.core.query.QueryModifier,
            bitecs.core.query.QueryOptions>>):bitecs.core.query.QueryResult;
    static overload function observe(world:{}, hook:{},
        callback:(eid:EntityId, args:Dynamic) -> Dynamic):() -> Void;
    static overload function observe(world:{}, hook:{},
        callback:(eid:EntityId, args:Dynamic) -> Void):() -> Void;
    static overload function observe(world:{}, hook:{}, callback:(eid:EntityId) -> Dynamic):() -> Void;
    static overload function observe(world:{}, hook:{}, callback:(eid:EntityId) -> Void):() -> Void;
    static function onAdd(terms:haxe.extern.Rest<Dynamic>):{};
    static function onRemove(terms:haxe.extern.Rest<Dynamic>):{};
    static function Or(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
    static function And(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
    static function Not(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
    static function Any(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
    static function All(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
    static function None(components:haxe.extern.Rest<Dynamic>):bitecs.core.query.OpReturnType;
    static function onGet(terms:haxe.extern.Rest<Dynamic>):{};
    static function onSet(terms:haxe.extern.Rest<Dynamic>):{};
    static function Hierarchy(relation:Dynamic, ?depth:Int):bitecs.core.query.HierarchyTerm;
    static function Cascade(relation:Dynamic, ?depth:Int):bitecs.core.query.HierarchyTerm;
    static final asBuffer:bitecs.core.query.QueryModifier;
    static final isNested:bitecs.core.query.QueryModifier;
    static final noCommit:bitecs.core.query.QueryModifier;
    static function pipe<T, U, R>(functions_0:T, functions_1:U,
        functions_2:R):(args:haxe.extern.Rest<Any>) -> js.lib.ReturnType<R>;
    static function withAutoRemoveSubject<T>(relation:bitecs.core.relation.Relation<T>):bitecs.core.relation.Relation<T>;
    static function withOnTargetRemoved<T>(onRemove:bitecs.core.relation.OnTargetRemovedCallback):(relation:bitecs.core.relation.Relation<T>) ->
        bitecs.core.relation.Relation<T>;
    static function withStore<T>(createStore:(eid:EntityId) ->
        T):(relation:bitecs.core.relation.Relation<T>) -> bitecs.core.relation.Relation<T>;
    @:overload(function<T>(options:{
        @:optional dynamic function store():T;
        @:optional var exclusive:Bool;
        @:optional var autoRemoveSubject:Bool;
        @:optional dynamic function onTargetRemoved(subject:EntityId, target:EntityId):Void;
    }):bitecs.core.relation.Relation<T> {})
    static function createRelation<T>(modifiers:haxe.extern.Rest<(relation:bitecs.core.relation.Relation<T>) ->
        bitecs.core.relation.Relation<T>>):bitecs.core.relation.Relation<T>;
    static function getRelationTargets(world:Dynamic, eid:EntityId,
        relation:bitecs.core.relation.Relation<Dynamic>):Array<Float>;
    static function Wildcard(target:bitecs.core.relation.RelationTarget):Dynamic;
    static function IsA(target:bitecs.core.relation.RelationTarget):Dynamic;
    static function Pair<T>(relation:bitecs.core.relation.Relation<T>,
        target:bitecs.core.relation.RelationTarget):T;
    static function isRelation(component:Dynamic):Bool;
    static function isWildcard(relation:Dynamic):Bool;
    static function getHierarchyDepth(world:{}, entity:EntityId, relation:Dynamic):Int;
    static function getMaxHierarchyDepth(world:{}, relation:Dynamic):Int;

}

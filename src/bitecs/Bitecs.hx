package bitecs;

import bitecs.Query.QueryType;

@:jsRequire("bitecs") @valueModuleOnly extern class Bitecs {

    static function setDefaultSize(size:Int):Void;
    @:overload(function(?size:Int):Any { })
    static function createWorld<W>(?obj:W, ?size:Int):W;
    static function resetWorld<W>(world:W):W;
    static function deleteWorld<W>(world:W):Void;
    static function addEntity<W>(world:W):Entity;
    static function removeEntity<W>(world:W, eid:Entity):Void;
    static function entityExists<W>(world:W, eid:Entity):Bool;
    static function getWorldComponents<W>(world:W):Array<Dynamic>;
    static function getAllEntities<W>(world:W):Array<Entity>;
    static function registerComponent<W>(world:W, component:Dynamic):Void;
    static function registerComponents<W>(world:W, components:Array<Dynamic>):Void;
    static function defineComponent(schema:Dynamic, ?size:Int):Dynamic;
    static function addComponent<W>(world:W, component:Dynamic, eid:Entity, ?reset:Bool):Void;
    static function removeComponent<W>(world:W, component:Dynamic, eid:Entity, ?reset:Bool):Void;
    static function hasComponent<W>(world:W, component:Dynamic, eid:Entity):Bool;
    static function getEntityComponents<W>(world:W, eid:Entity):Array<Dynamic>;
    static function defineQuery<W>(components:Array<Dynamic>):QueryType<W>;
    static function Changed<W>(c:Dynamic):Dynamic;
    static function Not<W>(c:Dynamic):Dynamic;
    static function enterQuery<W>(query:QueryType<W>):QueryType<W>;
    static function exitQuery<W>(query:QueryType<W>):QueryType<W>;
    static function resetChangedQuery<W>(world:W, query:QueryType<W>):QueryType<W>;
    static function removeQuery<W>(world:W, query:QueryType<W>):QueryType<W>;
    static function commitRemovals<W>(world:W):Void;
    static function defineSerializer<W>(target:Dynamic, ?maxBytes:Int):Dynamic->js.lib.ArrayBuffer;
    static function defineDeserializer<W>(target:Dynamic):(world:W, packet:js.lib.ArrayBuffer, ?mode:DESERIALIZE_MODE) -> Array<Entity>;
    static function pipe(fns:haxe.extern.Rest<(args:haxe.extern.Rest<Dynamic>) -> Dynamic>):(input:haxe.extern.Rest<Dynamic>) -> Dynamic;
    static final Types:{
        var i8:String;
        var ui8:String;
        var ui8c:String;
        var i16:String;
        var ui16:String;
        var i32:String;
        var ui32:String;
        var f32:String;
        var f64:String;
        var eid:String;
    };
    static final parentArray:js.lib.Symbol;

}

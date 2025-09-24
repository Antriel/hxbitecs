package bitecs.core;

@:jsRequire("bitecs/dist/core/Component") @valueModuleOnly extern class Component {
	@:overload(function(world:{ }, eid:Float, components:haxe.extern.Rest<Dynamic>):Void { })
	static function addComponents(world:{ }, eid:Float, components:Array<Dynamic>):Void;
	static function registerComponent(world:{ }, component:Dynamic):bitecs.core.component.ComponentData;
	static function registerComponents(world:{ }, components:Array<Dynamic>):Void;
	static function hasComponent(world:{ }, eid:Float, component:Dynamic):Bool;
	static function getComponent(world:{ }, eid:Float, component:Dynamic):Dynamic;
	static function set<T>(component:T, data:Dynamic):{
		var component : T;
		var data : Dynamic;
	};
	static function setComponent(world:{ }, eid:Float, component:Dynamic, data:Dynamic):Void;
	static function addComponent(world:{ }, eid:Float, componentOrSet:Dynamic):Bool;
	static function removeComponent(world:{ }, eid:Float, components:haxe.extern.Rest<Dynamic>):Void;
	static function removeComponents(world:{ }, eid:Float, components:haxe.extern.Rest<Dynamic>):Void;
}

package bitecs.core.utils;

@:jsRequire("bitecs/dist/core/utils/pipe") @valueModuleOnly extern class Pipe {
	static function pipe<T, U, R>(functions_0:T, functions_1:U, functions_2:R):(args:haxe.extern.Rest<Any>) -> js.lib.ReturnType<R>;
}

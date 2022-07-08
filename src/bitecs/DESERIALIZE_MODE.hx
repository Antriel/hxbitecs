package bitecs;

@:jsRequire("bitecs", "DESERIALIZE_MODE") @:enum extern abstract DESERIALIZE_MODE(Int) from Int to Int {

    var REPLACE;
    var APPEND;
    var MAP;

}

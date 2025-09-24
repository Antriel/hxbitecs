package bitecs.core.entityindex;

typedef EntityIndex = {
	var aliveCount : Float;
	var dense : Array<Float>;
	var sparse : Array<Float>;
	var maxId : Float;
	var versioning : Bool;
	var versionBits : Float;
	var entityMask : Float;
	var versionShift : Float;
	var versionMask : Float;
};

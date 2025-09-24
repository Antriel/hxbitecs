package bitecs.core.component;

typedef ComponentData = {
	var id : Float;
	var generationId : Float;
	var bitflag : Float;
	var ref : Dynamic;
	var queries : js.lib.Set<bitecs.core.query.Query>;
	var setObservable : bitecs.core.utils.observer.Observable;
	var getObservable : bitecs.core.utils.observer.Observable;
};

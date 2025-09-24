package bitecs.core.world;

typedef WorldContext = {
	var entityIndex : bitecs.core.entityindex.EntityIndex;
	var entityMasks : Array<Array<Float>>;
	var entityComponents : js.lib.Map<Float, js.lib.Set<Dynamic>>;
	var bitflag : Float;
	var componentMap : js.lib.Map<Dynamic, bitecs.core.component.ComponentData>;
	var componentCount : Float;
	var queries : js.lib.Set<bitecs.core.query.Query>;
	var queriesHashMap : js.lib.Map<String, bitecs.core.query.Query>;
	var notQueries : js.lib.Set<Dynamic>;
	var dirtyQueries : js.lib.Set<Dynamic>;
	var entitiesWithRelations : js.lib.Set<Float>;
	var hierarchyData : js.lib.Map<Dynamic, {
		var depths : js.lib.Uint32Array;
		var dirty : bitecs.core.utils.sparseset.SparseSet;
		var depthToEntities : js.lib.Map<Float, bitecs.core.utils.sparseset.SparseSet>;
		var maxDepth : Float;
	}>;
	var hierarchyActiveRelations : js.lib.Set<Dynamic>;
	var hierarchyQueryCache : js.lib.Map<Dynamic, {
		var hash : String;
		var result : bitecs.core.query.QueryResult;
	}>;
};

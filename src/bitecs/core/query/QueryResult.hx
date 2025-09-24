package bitecs.core.query;

import js.lib.ArrayBuffer;
import bitecs.core.entity.EntityId;

typedef QueryResult = ts.AnyOf2<ArrayBuffer, haxe.ds.ReadOnlyArray<EntityId>>;

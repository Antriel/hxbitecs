package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

/**
 * Entity wrapper type for type annotations and function parameters.
 *
 * Two usage forms:
 * - `HxEntity<World, [terms]>` - Specify world type and component terms directly
 * - `HxEntity<QueryType>` - Derive from a query typedef
 *
 * Both forms resolve to the same underlying EntityWrapper class, ensuring type compatibility.
 *
 * Example:
 * ```haxe
 * typedef PosVelQuery = HxQuery<MyWorld, [pos, vel]>;
 *
 * // These are equivalent types:
 * function moveEntity(e:HxEntity<MyWorld, [pos, vel]>) { }
 * function moveEntity(e:HxEntity<PosVelQuery>) { }
 * ```
 *
 * Entity wrappers are created via:
 * - `Hx.entity(world, eid, [terms])` - Returns `HxEntity<World, [terms]>`
 * - `query.entity(eid)` - Returns `HxEntity<World, [terms]>` matching the query's terms
 */
#if !macro
@:genericBuild(hxbitecs.HxEntity.build()) class HxEntity<World, Rest> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [world, terms]):
            // Two parameters: HxEntity<World, [terms]>
            var baseName = MacroUtils.getBaseName(world);
            var simpleTermInfo = TermUtils.parseTerms(world, terms, false);
            var name = 'EntityWrapper${baseName}_${simpleTermInfo.structureId}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () ->
                generateEntityWrapper(name, world, terms, simpleTermInfo));
        case TInst(_, [queryType]):
            // One parameter: HxEntity<QueryType>
            // Extract World and Terms from the QueryType
            return buildFromQueryType(queryType);

        case _:
            Context.error("HxEntity requires one or two type parameters", Context.currentPos());
    }
}

function buildFromQueryType(queryType:Type):ComplexType {
    var pos = Context.currentPos();

    // Get the entity method's return type from the query
    // This will be the already-generated EntityWrapper class
    try {
        var queryTypeE:Expr = {
            expr: ECheckType(macro null, TypeTools.toComplexType(queryType)),
            pos: pos
        };
        var entityMethodType = Context.typeof(macro $queryTypeE.entity(0));

        // Convert the entity method's return type directly to ComplexType
        // This is already the final EntityWrapper type, so we just return it
        return TypeTools.toComplexType(entityMethodType);
    } catch (e:Dynamic) {
        return
            Context.error('Failed to resolve entity wrapper type from query type ${TypeTools.toString(queryType)}: $e', pos);
    }
}

function generateEntityWrapper(name:String, world:Type, terms:Type,
        simpleTermInfo:TermUtils.QueryTermInfo):Array<TypeDefinition> {
    return EntityMacroUtils.generateEntityClass(name, world, simpleTermInfo.allComponents);
}
#end

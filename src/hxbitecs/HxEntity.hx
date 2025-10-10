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
            var termInfo = TermUtils.parseTerms(world, terms, true); // Allow operators
            var name = 'EntityWrapper${baseName}_${termInfo.structureId}';
            var ct = TPath({ pack: MacroUtils.HXBITECS_PACK, name: name });

            // Ensure EntityWrapper class is generated (needed for instantiation)
            MacroUtils.buildGenericType(name, ct, () -> generateEntityWrapper(name, world, terms, termInfo));

            // Return structural type instead of nominal class type
            return generateStructuralType(termInfo.allComponents);
        case TInst(_, [queryType]):
            // One parameter: HxEntity<QueryType>
            // Extract World and Terms from the QueryType
            return buildStructuralFromQueryType(queryType);

        case _:
            Context.error("HxEntity requires one or two type parameters", Context.currentPos());
    }
}

function buildStructuralFromQueryType(queryType:Type):ComplexType {
    var pos = Context.currentPos();

    // The trick: look at the HxQuery generic build parameters stored in the typedef
    // When we have `typedef PosVelQuery = HxQuery<World, [terms]>`, we want to extract
    // the original type parameters before they were resolved
    return switch queryType {
        case TType(_.get() => t, params) if (params.length == 2):
            // Typedef with preserved type parameters from HxQuery<World, Terms>
            var world = params[0];
            var terms = params[1];
            var termInfo = TermUtils.parseTerms(world, terms, true); // Allow operators
            generateStructuralType(termInfo.allComponents);
        case TType(_.get() => t, _):
            // Typedef without parameters - need to extract from the typedef's underlying type
            // The query.entity() method returns HxEntity<World, [terms]>, extract from there
            try {
                var queryTypeE:Expr = {
                    expr: ECheckType(macro null, TypeTools.toComplexType(queryType)),
                    pos: pos
                };
                var entityMethodType = Context.typeof(macro $queryTypeE.get(0));
                // The entity method returns our structural type, so return it directly
                return TypeTools.toComplexType(entityMethodType);
            } catch (e:Dynamic) {
                Context.error('Failed to resolve entity type from query: $e', pos);
            }
        case TAbstract(_, [world, terms]):
            // Direct HxQuery<World, [terms]> without typedef
            var termInfo = TermUtils.parseTerms(world, terms, true); // Allow operators
            generateStructuralType(termInfo.allComponents);
        case _:
            Context.error('Unable to extract World and terms from query type ${TypeTools.toString(queryType)}', pos);
    }
}

function generateStructuralType(componentInfos:Array<TermUtils.TermInfo>):ComplexType {
    var fields:Array<Field> = [];
    var pos = Context.currentPos();

    // Add eid field (allow structural subtyping from final field in class)
    fields.push({
        name: "eid",
        kind: FVar(TPath({ pack: [], name: 'Int' })),
        pos: pos,
        access: [APublic, AFinal]
    });

    // Add component fields matching EntityWrapper's public API
    for (termInfo in componentInfos) {
        var pattern = MacroUtils.analyzeComponentType(termInfo.componentType);
        // All component patterns use HxComponent wrapper for consistency
        var fieldKind:FieldType = FVar(TPath({
            pack: MacroUtils.HXBITECS_PACK,
            name: MacroUtils.HX_COMPONENT,
            params: [TPType(TypeTools.toComplexType(termInfo.componentType))]
        }));

        fields.push({
            name: termInfo.name,
            kind: fieldKind,
            pos: pos,
            access: [APublic, AFinal]
        });
    }
    return TAnonymous(fields);
}

function generateEntityWrapper(name:String, world:Type, terms:Type,
        simpleTermInfo:TermUtils.QueryTermInfo):Array<TypeDefinition> {
    return EntityMacroUtils.generateEntityClass(name, world, simpleTermInfo.allComponents);
}
#end

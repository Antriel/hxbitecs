package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.EntityAccessorMacro.build()) class EntityAccessorMacro<World, Rest> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [world, terms]):
            var baseName = MacroUtils.getBaseName(world);
            var simpleTermInfo = TermUtils.parseTerms(world, terms, false);
            var name = 'EntityAccessor${baseName}_${simpleTermInfo.structureId}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () ->
                generateEntityAccessor(name, world, terms, simpleTermInfo));
        case _:
            Context.error("EntityAccessorMacro requires exactly two type parameters", Context.currentPos());
    }
}

function generateEntityAccessor(name:String, world:Type, terms:Type,
        simpleTermInfo:TermUtils.QueryTermInfo):Array<TypeDefinition> {
    return EntityMacroUtils.generateEntityClass(name, world, simpleTermInfo.allComponents, Accessor);
}
#end

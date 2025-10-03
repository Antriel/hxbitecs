package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.EntityWrapperMacro.build()) class EntityWrapperMacro<World, Rest> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [world, terms]):
            var baseName = MacroUtils.getBaseName(world);
            var queryTermInfo = TermUtils.parseTerms(world, terms);
            var name = 'EntityWrapper${baseName}_${queryTermInfo.structureId}';
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            return MacroUtils.buildGenericType(name, ct, () ->
                generateWrapper(name, world, queryTermInfo.allComponents));
        case _:
            Context.error("EntityWrapperMacro requires exactly two type parameters", Context.currentPos());
    }
}

function generateWrapper(name:String, world:Type, termInfos:Array<TermUtils.TermInfo>):Array<TypeDefinition> {
    return EntityMacroUtils.generateEntityClass(name, world, termInfos);
}
#end

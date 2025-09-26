package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

using Lambda;

typedef TermInfo = {

    name:String,
    componentType:Type

}

function parseTerms(worldType:Type, termsType:Type):Array<TermInfo> {
    var termNames = getTermFields(termsType);
    var termInfos:Array<TermInfo> = [];

    for (name in termNames) {
        var componentType = getWorldComponentType(worldType, name);
        termInfos.push({
            name: name,
            componentType: componentType
        });
    }

    return termInfos;
}

function getTermFields(terms:Type):Array<String> {
    return switch terms {
        case TInst(_.get().kind => KExpr({ expr: EArrayDecl(values) }), _):
            var fields = [];
            for (v in values) switch v.expr {
                case EConst(CIdent(s)): fields.push(s);
                case _: Context.error('Unsupported term type: $v', v.pos);
            }
            fields;
        case _:
            Context.error('Expected TInst(KExpr(EArrayDecl())) for terms, got: $terms', Context.currentPos());
    }
}

function getWorldComponentType(worldType:Type, fieldName:String):Type {
    return switch worldType {
        case TAnonymous(a):
            var field = a.get().fields.find(f -> f.name == fieldName);
            if (field == null) {
                Context.error('Component field "$fieldName" not found in world type', Context.currentPos());
            }
            field.type;
        case TInst(t, _):
            var field = t.get().fields.get().find(f -> f.name == fieldName);
            if (field == null) {
                Context.error('Component field "$fieldName" not found in world type', Context.currentPos());
            }
            field.type;
        case TType(t, _):
            getWorldComponentType(t.get().type, fieldName);
        case _:
            Context.error('Unsupported world type $worldType for component extraction', Context.currentPos());
    }
}
#end

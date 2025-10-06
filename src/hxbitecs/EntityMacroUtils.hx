package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import hxbitecs.MacroDebug;
#end

#if macro

typedef EntityComponentInfo = {

    name:String,
    wrapperType:ComplexType,
    pattern:MacroUtils.ComponentPattern

}

function generateEntityClass(name:String, world:Type,
        termInfos:Array<TermUtils.TermInfo>):Array<TypeDefinition> {
    final pos = Context.currentPos();
    var fields:Array<Field> = [];

    // Generate component wrapper info
    var componentWrappers = generateEntityComponentInfo(termInfos);

    // Add wrapper-specific fields and constructor (only Wrapper type now)
    fields = fields.concat(generateWrapperSpecificFields(componentWrappers));

    // Add component wrapper fields (all public final)
    fields = fields.concat(generateComponentFields(componentWrappers));

    var classDef:TypeDefinition = {
        name: name,
        pack: MacroUtils.HXBITECS_PACK,
        pos: pos,
        kind: TDClass(),
        fields: fields
    };

    MacroDebug.printTypeDefinition(classDef, name);
    return [classDef];
}

function generateEntityComponentInfo(termInfos:Array<TermUtils.TermInfo>):Array<EntityComponentInfo> {
    var componentWrappers:Array<EntityComponentInfo> = [];

    for (termInfo in termInfos) {
        var pattern = MacroUtils.analyzeComponentType(termInfo.componentType);

        var wrapperType:ComplexType = switch pattern {
            case SimpleArray(_):
                // For SimpleArray, use raw array type since we store it directly
                TypeTools.toComplexType(termInfo.componentType);
            case SoA(_) | AoS(_) | Tag:
                // For other patterns, use HxComponent
                TPath({
                    pack: MacroUtils.HXBITECS_PACK,
                    name: MacroUtils.HX_COMPONENT,
                    params: [TPType(TypeTools.toComplexType(termInfo.componentType))]
                });
        };

        componentWrappers.push({
            name: termInfo.name,
            wrapperType: wrapperType,
            pattern: pattern
        });
    }

    return componentWrappers;
}

function generateWrapperSpecificFields(componentWrappers:Array<EntityComponentInfo>):Array<Field> {
    var fields:Array<Field> = [];

    // Add eid and components fields
    fields.push(MacroUtils.generateBasicField("eid", TPath({ pack: [], name: 'Int' }), [APublic, AFinal]));
    fields.push(MacroUtils.generateBasicField("components", TPath({ pack: [], name: 'Array', params: [TPType(TPath({ pack: [], name: 'Dynamic' }))] }), [APublic, AFinal]));

    // Constructor
    var constructorExprs = [
        macro this.eid = eid,
        macro this.components = components
    ];

    // Add component wrapper initialization
    constructorExprs = constructorExprs.concat(generateComponentConstructorExprs(componentWrappers));

    fields.push(MacroUtils.generateConstructorField([
        { name: "eid", type: TPath({ pack: [], name: 'Int' }) },
        { name: "components", type: TPath({ pack: [], name: 'Array', params: [TPType(TPath({ pack: [], name: 'Dynamic' }))] }) }
    ], constructorExprs));

    return fields;
}

function generateComponentFields(componentWrappers:Array<EntityComponentInfo>):Array<Field> {
    var fields:Array<Field> = [];
    var pos = Context.currentPos();

    for (wrapper in componentWrappers) {
        switch wrapper.pattern {
            case SimpleArray(elementType):
                // For SimpleArray, generate properties with get/set directly on entity
                // The get/set methods will access stored array references
                var elementComplexType = TypeTools.toComplexType(elementType);
                var storeName = '${wrapper.name}Store';

                // Private storage field for the array reference (raw array type)
                var arrayType = TPath({
                    pack: [],
                    name: "Array",
                    params: [TPType(elementComplexType)]
                });
                fields.push(MacroUtils.generateBasicField(storeName, arrayType, [APrivate, AFinal]));

                // Property with get/set methods using helper
                var getterExpr = macro this.$storeName[this.eid];
                var propFields = MacroUtils.generatePropertyWithGetSet(wrapper.name, elementComplexType, getterExpr);
                fields = fields.concat(propFields);

            case SoA(_) | AoS(_) | Tag:
                // For other patterns, keep existing approach with wrapper fields
                fields.push({
                    name: wrapper.name,
                    kind: FVar(wrapper.wrapperType),
                    pos: pos,
                    access: [APublic, AFinal]
                });
        }
    }

    return fields;
}

function generateComponentConstructorExprs(componentWrappers:Array<EntityComponentInfo>):Array<Expr> {
    var constructorExprs:Array<Expr> = [];
    var componentIndex = 0;

    for (wrapper in componentWrappers) {
        constructorExprs.push(generateSingleComponentConstructorExpr(wrapper, componentIndex));
        componentIndex++;
    }

    return constructorExprs;
}

function generateSingleComponentConstructorExpr(wrapper:EntityComponentInfo, componentIndex:Int):Expr {
    var fieldName = wrapper.name;
    var wrapperTypePath = switch wrapper.wrapperType {
        case TPath(p): p;
        case _: Context.error('Unexpected wrapper type for $fieldName', Context.currentPos());
    };

    return switch wrapper.pattern {
        case SoA(_) | AoS(_):
            generateStoreWrapperConstructorExpr(fieldName, wrapperTypePath, componentIndex);
        case SimpleArray(_):
            generateSimpleArrayConstructorExpr(fieldName, componentIndex);
        case Tag:
            macro this.$fieldName = new $wrapperTypePath(eid);
    };
}

function generateStoreWrapperConstructorExpr(fieldName:String, wrapperTypePath:TypePath,
        componentIndex:Int):Expr {
    var index = macro $v{componentIndex};
    return macro this.$fieldName = new $wrapperTypePath({
        store: components[$index],
        eid: eid
    });
}

function generateSimpleArrayConstructorExpr(fieldName:String, componentIndex:Int):Expr {
    var storeName = '${fieldName}Store';
    var index = macro $v{componentIndex};
    return macro this.$storeName = components[$index];
}
#end

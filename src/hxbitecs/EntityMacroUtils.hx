package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import hxbitecs.MacroDebug;
#end

#if macro
enum EntityClassType {

    Accessor; // EntityAccessor: world+eid constructor, public final component fields
    Wrapper; // EntityWrapper: eid+query constructor, public final component fields

}

typedef EntityComponentInfo = {

    name:String,
    wrapperType:ComplexType,
    pattern:MacroUtils.ComponentPattern

}

function generateEntityClass(name:String, world:Type, termInfos:Array<TermUtils.TermInfo>,
        classType:EntityClassType):Array<TypeDefinition> {
    final pos = Context.currentPos();
    var fields:Array<Field> = [];

    // Generate component wrapper info
    var componentWrappers = generateEntityComponentInfo(termInfos);

    // Add class-specific basic fields and constructor
    switch classType {
        case Accessor:
            fields = fields.concat(generateAccessorSpecificFields(world, componentWrappers));
        case Wrapper:
            fields = fields.concat(generateWrapperSpecificFields(componentWrappers));
    }

    // Add component wrapper fields (all public final)
    fields = fields.concat(generateComponentFields(componentWrappers));

    var classDef:TypeDefinition = {
        name: name,
        pack: ['hxbitecs'],
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
                // For other patterns, use ComponentWrapperMacro
                TPath({
                    pack: ['hxbitecs'],
                    name: 'ComponentWrapperMacro',
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

function generateAccessorSpecificFields(world:Type,
        componentWrappers:Array<EntityComponentInfo>):Array<Field> {
    var fields:Array<Field> = [];

    // Add world and eid fields
    fields.push(MacroUtils.generateBasicField("world", TypeTools.toComplexType(world), [APublic, AFinal]));
    fields.push(MacroUtils.generateBasicField("eid", TPath({ pack: [], name: "Int" }), [APublic, AFinal]));

    // Constructor
    var constructorExprs = [
        macro this.world = world,
        macro this.eid = eid
    ];

    // Add component wrapper initialization
    constructorExprs = constructorExprs.concat(generateComponentConstructorExprs(componentWrappers, Accessor));

    fields.push(MacroUtils.generateConstructorField([
        { name: "world", type: TypeTools.toComplexType(world) },
        { name: "eid", type: TPath({ pack: [], name: "Int" }) }
    ], constructorExprs));

    return fields;
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
    constructorExprs = constructorExprs.concat(generateComponentConstructorExprs(componentWrappers, Wrapper));

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

                // Property with get/set methods
                var arrayRef = { expr: EConst(CIdent(storeName)), pos: pos };
                var eid = { expr: EConst(CIdent("eid")), pos: pos };
                var getterExpr = { expr: EArray(arrayRef, eid), pos: pos };

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

function generateComponentConstructorExprs(componentWrappers:Array<EntityComponentInfo>,
        classType:EntityClassType):Array<Expr> {
    var constructorExprs:Array<Expr> = [];
    var componentIndex = 0;

    for (wrapper in componentWrappers) {
        constructorExprs.push(generateSingleComponentConstructorExpr(wrapper, classType, componentIndex));
        componentIndex++;
    }

    return constructorExprs;
}

function generateSingleComponentConstructorExpr(wrapper:EntityComponentInfo, classType:EntityClassType,
        componentIndex:Int):Expr {
    var fieldName = wrapper.name;
    var wrapperTypePath = switch wrapper.wrapperType {
        case TPath(p): p;
        case _: Context.error('Unexpected wrapper type for $fieldName', Context.currentPos());
    };

    return switch wrapper.pattern {
        case SoA(_) | AoS(_):
            generateStoreWrapperConstructorExpr(fieldName, wrapperTypePath, classType, componentIndex);
        case SimpleArray(_):
            generateSimpleArrayConstructorExpr(fieldName, classType, componentIndex);
        case Tag:
            macro this.$fieldName = new $wrapperTypePath(eid);
    };
}

function generateStoreWrapperConstructorExpr(fieldName:String, wrapperTypePath:TypePath,
        classType:EntityClassType, componentIndex:Int):Expr {
    return switch classType {
        case Accessor:
            macro this.$fieldName = new $wrapperTypePath({
                store: world.$fieldName,
                eid: eid
            });
        case Wrapper:
            var index = macro $v{componentIndex};
            macro this.$fieldName = new $wrapperTypePath({
                store: components[$index],
                eid: eid
            });
    };
}

function generateSimpleArrayConstructorExpr(fieldName:String, classType:EntityClassType,
        componentIndex:Int):Expr {
    var storeName = '${fieldName}Store';
    return switch classType {
        case Accessor:
            macro this.$storeName = world.$fieldName;
        case Wrapper:
            var index = macro $v{componentIndex};
            macro this.$storeName = components[$index];
    };
}
#end

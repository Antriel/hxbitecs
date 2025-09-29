package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if macro
enum EntityClassType {
    Accessor; // EntityAccessor: world+eid constructor, public final component fields
    Wrapper;  // EntityWrapper: eid+query constructor, public final component fields
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

    trace(new haxe.macro.Printer().printTypeDefinition(classDef));
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

function generateAccessorSpecificFields(world:Type, componentWrappers:Array<EntityComponentInfo>):Array<Field> {
    var pos = Context.currentPos();
    var fields:Array<Field> = [];

    // Add world and eid fields
    fields.push({
        name: "world",
        kind: FVar(TypeTools.toComplexType(world)),
        pos: pos,
        access: [APublic, AFinal]
    });

    fields.push({
        name: "eid",
        kind: FVar(TPath({ pack: [], name: "Int" })),
        pos: pos,
        access: [APublic, AFinal]
    });

    // Constructor
    var constructorExprs = [
        macro this.world = world,
        macro this.eid = eid
    ];

    // Add component wrapper initialization
    constructorExprs = constructorExprs.concat(generateComponentConstructorExprs(componentWrappers, Accessor));

    fields.push({
        name: "new",
        kind: FFun({
            args: [
                { name: "world", type: TypeTools.toComplexType(world) },
                { name: "eid", type: TPath({ pack: [], name: "Int" }) }
            ],
            ret: null,
            expr: { expr: EBlock(constructorExprs), pos: pos }
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    return fields;
}

function generateWrapperSpecificFields(componentWrappers:Array<EntityComponentInfo>):Array<Field> {
    var pos = Context.currentPos();
    var fields:Array<Field> = [];

    // Add query and eid fields
    fields.push({
        name: "query",
        kind: FVar(TPath({ pack: ['bitecs', 'core', 'query'], name: 'Query' })),
        pos: pos,
        access: [APublic, AFinal]
    });

    fields.push({
        name: "eid",
        kind: FVar(TPath({ pack: [], name: 'Int' })),
        pos: pos,
        access: [APublic, AFinal]
    });

    // Constructor
    var constructorExprs = [
        macro this.eid = eid,
        macro this.query = query
    ];

    // Add component wrapper initialization
    constructorExprs = constructorExprs.concat(generateComponentConstructorExprs(componentWrappers, Wrapper));

    fields.push({
        name: "new",
        kind: FFun({
            args: [
                { name: "eid", type: TPath({ pack: [], name: 'Int' }) },
                { name: "query", type: TPath({ pack: ['bitecs', 'core', 'query'], name: 'Query' }) }
            ],
            ret: null,
            expr: { expr: EBlock(constructorExprs), pos: pos }
        }),
        pos: pos,
        access: [APublic, AInline]
    });

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
                fields.push({
                    name: storeName,
                    kind: FVar(arrayType),
                    pos: pos,
                    access: [APrivate, AFinal]
                });

                // Property with get/set methods
                var accessExprs = MacroUtils.generateSimpleArrayAccessExprs(
                    { expr: EConst(CIdent(storeName)), pos: pos },
                    { expr: EConst(CIdent("eid")), pos: pos }
                );

                var propFields = MacroUtils.generatePropertyWithGetSet(
                    wrapper.name,
                    elementComplexType,
                    accessExprs.get,
                    accessExprs.set
                );

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
        var fieldName = wrapper.name;
        var wrapperTypePath = switch wrapper.wrapperType {
            case TPath(p): p;
            case _: Context.error('Unexpected wrapper type for $fieldName', Context.currentPos());
        };

        switch wrapper.pattern {
            case SoA(_) | AoS(_):
                switch classType {
                    case Accessor:
                        constructorExprs.push(macro this.$fieldName = new $wrapperTypePath({
                            store: world.$fieldName,
                            eid: eid
                        }));
                    case Wrapper:
                        var index = macro $v{componentIndex};
                        constructorExprs.push(macro this.$fieldName = new $wrapperTypePath({
                            store: query.allComponents[$index],
                            eid: eid
                        }));
                }
            case SimpleArray(_):
                // For SimpleArray, store direct array reference (not wrapper instance)
                var storeName = '${fieldName}Store';
                switch classType {
                    case Accessor:
                        constructorExprs.push(macro this.$storeName = world.$fieldName);
                    case Wrapper:
                        var index = macro $v{componentIndex};
                        constructorExprs.push(macro this.$storeName = query.allComponents[$index]);
                }
            case Tag:
                constructorExprs.push(macro this.$fieldName = new $wrapperTypePath(eid));
        }
        componentIndex++;
    }

    return constructorExprs;
}
#end
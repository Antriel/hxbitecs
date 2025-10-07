package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import hxbitecs.MacroDebug;
#end

#if !macro
@:genericBuild(hxbitecs.HxComponent.build()) class HxComponent<T> { }

#else
function build() {
    return switch Context.getLocalType() {
        case TInst(_, [componentType]):
            // Get the base name from the ORIGINAL type (before following typedefs/abstracts)
            // This preserves typedef names like "Player" instead of getting "Array"
            var baseName = MacroUtils.getBaseName(componentType);

            // Check if componentType is a typedef or abstract (not an inline type)
            var isNamedType = switch componentType {
                case TType(_, _) | TAbstract(_, _): true;
                case _: false;
            };

            var pattern = MacroUtils.analyzeComponentType(componentType);
            var pos = Context.currentPos();

            // Extract @:wrapperUsing metadata if present
            var usingPath = extractWrapperUsingMetadata(componentType);

            var name = switch pattern {
                case SoA(_): 'SoAWrapper_${baseName}';
                case AoS(elementType):
                    // If componentType is a named type (typedef/abstract), use only baseName
                    // Otherwise, include element field names for anonymous inline types
                    if (isNamedType) {
                        'AoSWrapper_${baseName}';
                    } else {
                        var elementName = MacroUtils.getBaseName(elementType);
                        'AoSWrapper_${baseName}_${elementName}';
                    }
                case SimpleArray(elementType):
                    // If componentType is a named type (typedef/abstract), use only baseName
                    // Otherwise, include element type name for inline Array types
                    if (isNamedType) {
                        'SimpleArrayWrapper_${baseName}';
                    } else {
                        var elementName = MacroUtils.getBaseName(elementType);
                        'SimpleArrayWrapper_${baseName}_${elementName}';
                    }
                case Tag: 'TagWrapper_${baseName}';
            };

            var ct = TPath({ pack: MacroUtils.HXBITECS_PACK, name: name });
            return MacroUtils.buildGenericType(name, ct, () -> switch pattern {
                case SoA(fields):
                    generateStoreWrapper(name, componentType, fields, generateSoAAccess, usingPath);
                case AoS(elementType):
                    var fields = extractAoSFields(elementType);
                    generateStoreWrapper(name, componentType, fields, generateAoSAccess, usingPath);
                case SimpleArray(elementType):
                    generateSimpleArrayWrapper(name, componentType, elementType, usingPath);
                case Tag:
                    generateTagWrapper(name, componentType, usingPath);
            });
        case _:
            Context.error("HxComponent requires exactly one type parameter", Context.currentPos());
    }
}

function extractWrapperUsingMetadata(componentType:Type):Null<Expr> {
    // Follow the type to get to the actual definition (handles typedefs)
    var followedType = Context.follow(componentType);

    // Try to get metadata from the original type (before following)
    var metadata = switch componentType {
        case TType(t, _):
            t.get().meta;
        case TInst(t, _):
            t.get().meta;
        case TAbstract(t, _):
            t.get().meta;
        case _:
            null;
    };

    if (metadata != null && metadata.has(':wrapperUsing')) {
        var metaEntry = metadata.extract(':wrapperUsing')[0];
        if (metaEntry != null && metaEntry.params != null && metaEntry.params.length > 0) {
            // Return the expression directly without parsing
            return metaEntry.params[0];
        }
    }

    return null;
}

function extractAoSFields(elementType:Type):Array<{name:String, type:Type}> {
    // Follow typedefs to get to the actual anonymous structure
    var followedType = Context.follow(elementType);
    return switch followedType {
        case TAnonymous(a):
            [for (field in a.get().fields) { name: field.name, type: field.type }];
        case _:
            Context.error('AoS element type must be anonymous structure (got: $followedType)', Context.currentPos());
    };
}

function generateSoAAccess(fieldName:String):Expr {
    return macro this.store.$fieldName[this.eid];
}

function generateAoSAccess(fieldName:String):Expr {
    return macro this.store[this.eid].$fieldName;
}

function generateStoreWrapper(name:String, componentType:Type, fields:Array<{name:String, type:Type}>,
        accessGenerator:(fieldName:String) -> Expr, usingPath:Null<Expr>):Array<TypeDefinition> {
    var pos = Context.currentPos();

    // Create the underlying type: {store: ComponentType, eid: Int}
    var underlyingType:ComplexType = TAnonymous([
        {
            name: "store",
            kind: FVar(TypeTools.toComplexType(componentType)),
            pos: pos,
            access: []
        },
        {
            name: "eid",
            kind: FVar(TPath({ pack: [], name: "Int" })),
            pos: pos,
            access: []
        }
    ]);

    var wrapperFields:Array<Field> = [];

    // Constructor
    wrapperFields.push({
        name: "new",
        kind: FFun({
            args: [{ name: "v", type: underlyingType }],
            ret: null,
            expr: macro this = v
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    // Generate getter/setter properties for each field
    for (field in fields) {
        var fieldName = field.name;
        var fieldType = TypeTools.toComplexType(field.type);
        var getterExpr = accessGenerator(fieldName);

        var propertyFields = MacroUtils.generatePropertyWithGetSet(fieldName, fieldType, getterExpr);
        wrapperFields = wrapperFields.concat(propertyFields);
    }

    return [createWrapperTypeDefinition(name, underlyingType, wrapperFields, usingPath)];
}

function generateTagWrapper(name:String, componentType:Type, usingPath:Null<Expr>):Array<TypeDefinition> {
    var pos = Context.currentPos();
    var wrapperFields:Array<Field> = [];

    // Constructor
    wrapperFields.push({
        name: "new",
        kind: FFun({
            args: [{ name: "eid", type: TPath({ pack: [], name: "Int" }) }],
            ret: null,
            expr: macro this = eid
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    // Build metadata array
    var metadata = MacroUtils.buildMetadataArray(usingPath, pos);

    var td = {
        name: name,
        pack: MacroUtils.HXBITECS_PACK,
        pos: pos,
        kind: TDAbstract(TPath({ pack: [], name: "Int" })),
        fields: wrapperFields,
        meta: metadata
    };
    MacroDebug.printTypeDefinition(td, name);
    return [td];
}

function generateSimpleArrayWrapper(name:String, componentType:Type, elementType:Type, usingPath:Null<Expr>):Array<TypeDefinition> {
    var pos = Context.currentPos();

    // Create the underlying type: {store: Array<T>, eid: Int}
    var elementComplexType = TypeTools.toComplexType(elementType);
    var underlyingType:ComplexType = TAnonymous([
        {
            name: "store",
            kind: FVar(TypeTools.toComplexType(componentType)),
            pos: pos,
            access: []
        },
        {
            name: "eid",
            kind: FVar(TPath({ pack: [], name: "Int" })),
            pos: pos,
            access: []
        }
    ]);

    var wrapperFields:Array<Field> = [];

    // Constructor
    wrapperFields.push({
        name: "new",
        kind: FFun({
            args: [{ name: "v", type: underlyingType }],
            ret: null,
            expr: macro this = v
        }),
        pos: pos,
        access: [APublic, AInline]
    });

    // Generate property with get/set for 'value' field
    var getterExpr = macro this.store[this.eid];
    var propFields = MacroUtils.generatePropertyWithGetSet("value", elementComplexType, getterExpr);
    wrapperFields = wrapperFields.concat(propFields);

    return [createWrapperTypeDefinition(name, underlyingType, wrapperFields, usingPath)];
}

function createWrapperTypeDefinition(name:String, underlyingType:ComplexType,
        fields:Array<Field>, usingPath:Null<Expr>):TypeDefinition {
    var pos = Context.currentPos();

    // Build metadata array
    var metadata = MacroUtils.buildMetadataArray(usingPath, pos);

    var td = {
        name: name,
        pack: MacroUtils.HXBITECS_PACK,
        pos: pos,
        kind: TDAbstract(underlyingType),
        fields: fields,
        meta: metadata
    };
    MacroDebug.printTypeDefinition(td, name);
    return td;
}
#end

package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
#end

#if !macro
@:genericBuild(hxbitecs.SoA.build()) class SoA<T> {}
#else 
@:persistent private var generated = new Map<String, Bool>();

function build() {
    return switch Context.getLocalType() {
        case TInst(_, [target]):
            var baseName = getBaseName(target);
            var name = 'SoA' + baseName;
            var ct = TPath({ pack: ['hxbitecs'], name: name });

            if (generated.exists(name)) {
                if (isAlive(ct, Context.currentPos())) {
                    // Sys.println('Reusing previously generated type for $name.');
                    return ct;
                }
                // Sys.println('Previously generated type for $name has been discarded.');
            }

            // Sys.println('Generating type for $name.');
            final td = generateSoA(target);
            td.name = name;
            // trace(new haxe.macro.Printer().printTypeDefinition(td));
            Context.defineType(td);
            generated.set(name, true);
            return ct;
        case _:
            Context.error("SoA requires exactly one type parameter", Context.currentPos());
    }
}

function isAlive(ct:ComplexType, pos:Position):Bool {
    return try Context.resolveType(ct, pos) != null catch (e) false;
}

function getBaseName(type:Type):String {
    return switch type {
        case TType(t, _): t.get().name;
        case TAnonymous(a):
            "Anon_" + 
            haxe.macro.PositionTools.toLocation(Context.currentPos()).range.start.line;
        case _: Context.error('Unsupported type $type for SoA', Context.currentPos());
    }
}

function toSoA(field:ClassField):Field {
    var fieldType = TypeTools.toComplexType(field.type);
    if (fieldType == null) {
        Context.error('Unable to convert field type ${field.name}', Context.currentPos());
    }

    return {
        name: field.name,
        kind: FVar(macro :Array<$fieldType>),
        pos: Context.currentPos()
    }
}

function generateSoA(target:Type):TypeDefinition {
    final pos = Context.currentPos();
    var structFields = [];

    switch target {
        case TAnonymous(a):
            structFields = a.get().fields.map(toSoA);
        case TType(t, params):
            var typeRef = t.get();
            switch (typeRef.type) {
                case TAnonymous(a):
                    structFields = a.get().fields.map(toSoA);
                case _:
                    Context.error('SoA can only be used with anonymous structures or typedefs of anonymous structures', pos);
            }
        case _:
            Context.error('SoA can only be used with anonymous structures or typedefs of anonymous structures', pos);
    }

    // Create the structure type from the fields
    var structType = ComplexType.TAnonymous(structFields);

    // Create constructor that initializes this = { field1: [], field2: [], ... }
    var structInitFields = {
        expr: EObjectDecl(structFields.map(field -> ({ field: field.name, expr: macro [] }:ObjectField))),
        pos: pos
    };

    var constructor:Field = {
        name: "new",
        kind: FFun({
            args: [],
            ret: null,
            expr: macro this = $structInitFields
        }),
        pos: pos,
        access: [APublic, AInline]
    };

    return {
        name: null,
        pack: ['hxbitecs'],
        pos: pos,
        kind: TDAbstract(structType),
        meta: [{ name: ":forward", pos: pos }],
        fields: [constructor]
    };
}

#end

package bitecs;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;
import tink.macro.BuildCache;

using tink.MacroApi;

function build() {
    return switch Context.getLocalType() {
        case TInst(t, params):
            var compTypes = Lambda.flatten([for (param in params) World.parseComponent(param)]).map(c -> c.type);
            var iterType = BuildCache.getTypeN('bitecs.gen.Query', compTypes, ctx -> new QueryBuilder(ctx).build());
            // BuildCache doesn't like building abstract, so we build the actual iterator, but we want to return the abstract.
            switch TypeTools.toComplexType(iterType) {
                case TPath(p):
                    p.name += 'Wrapper';
                    TPath(p);
                case _: throw "unexpected";
            }
        case _: throw "unexpected";
    }
}

private final entityType = macro:bitecs.Entity;
private final entityArrayType = macro:Array<bitecs.Entity>;
private final intType = macro:Int;

class QueryBuilder {

    final ctx:BuildContextN;
    final stores:Array<{
        name:String,
        type:ComplexType,
        wrapperPath:TypePath,
        compExactName:String
    }>;
    final worldType:ComplexType;
    final queryType:ComplexType;

    public function new(ctx:BuildContextN) {
        this.ctx = ctx;
        stores = ctx.types.map(t -> World.components.get(t)).map(c -> {
            name: c.name,
            type: c.def.storeType,
            wrapperPath: c.def.wrapperPath,
            compExactName: c.def.exactName
        });
        // for (s in stores) trace(ComplexType.TPath(s.wrapperPath).toType());
        worldType = TAnonymous(stores.map(s -> ({ name: s.name, kind: FVar(s.type), pos: ctx.pos, access: [AFinal] }:Field)));
        queryType = macro:bitecs.Query.QueryType<$worldType>;
    }

    public function build():TypeDefinition {
        defineQueryWrapper();
        return defineIterator();
    }

    function defineIterator() {
        // TODO should make sure the `ents`, `length` and `i` are not clashing with the store names.
        var args = [
            { name: 'ents', type: entityArrayType }
        ].concat(stores);
        var fields:Array<Field> = args.map(arg -> ({
            name: arg.name,
            pos: ctx.pos,
            access: [AFinal, APublic],
            kind: FVar(arg.type)
        }:Field));
        fields.push({ name: 'eid', pos: ctx.pos, kind: FVar(entityType), access: [APublic] });
        fields.push({ name: 'i', pos: ctx.pos, kind: FVar(intType, macro 0) });
        fields.push({ name: 'length', pos: ctx.pos, kind: FVar(intType), access: [APublic] });
        var newExpr = args.map(a -> {
            var aname = a.name;
            macro this.$aname = $i{aname};
        }).toBlock();
        newExpr = newExpr.concat(macro this.length = ents.length);
        final mNew = Member.method('new', ({ args: args, expr: newExpr }:Function));
        mNew.isBound = true;
        final mHasNext = Member.method('hasNext', ({ args: [], expr: macro return i < length }:Function));
        mHasNext.isBound = true;

        final mNext = Member.method('next', ({
            args: [],
            expr: macro {
                eid = ents[i++];
                return getWrapper(eid);
            }
        }:Function));
        mNext.isBound = true;

        final mGetWrapper = Member.method('getWrapper', ({
            args: [{ name: 'eid', type: entityType }],
            expr: EReturn(EObjectDecl(stores.map(s ->
                ({ field: s.name, expr: ENew(s.wrapperPath, [macro eid, macro $i{s.name}]).at() }:ObjectField))).at()).at()
        }:Function));
        mGetWrapper.isBound = true;
        final mReset = Member.method('reset', { args: [], expr: macro i = 0 });
        mReset.isBound = true;

        var iteratorTd:TypeDefinition = {
            pack: ['bitecs', 'gen'],
            name: ctx.name,
            pos: ctx.pos,
            kind: TDClass(),
            meta: [{
                name: ':using',
                pos: Context.currentPos(),
                params: [macro bitecs.QueryExtensions]
            }],
            fields: fields.concat([mNew, mHasNext, mNext, mGetWrapper, mReset])
        }
        // trace(new haxe.macro.Printer().printTypeDefinition(iteratorTd));
        return iteratorTd;
    }

    function defineQueryWrapper() {
        var selfCt = 'bitecs.gen.${ctx.name}Wrapper'.asComplexType();
        var selfTp = 'bitecs.gen.${ctx.name}Wrapper'.asTypePath();
        var helperTp = 'bitecs.gen.${ctx.name}Helper'.asTypePath();
        var firstHelperTp = 'bitecs.gen.${ctx.name}FirstHelper'.asTypePath();

        var storeExprs = stores.map(s -> (macro w).field(s.name));
        var mNew = Member.method('new', ({
            args: [{ name: 'w', type: worldType }],
            expr: macro this = cast Bitecs.defineQuery([$a{storeExprs}])
        }:Function));
        mNew.isBound = true;

        var mInit = Member.method('init', ({
            args: [{ name: 'w', type: worldType }],
            expr: macro this = cast Bitecs.defineQuery([$a{storeExprs}])
        }:Function));
        mInit.isBound = true;

        var mIterator = Member.method('iterator', ({
            args: [{ name: 'w', type: worldType }],
            expr: {
                var params = [macro this(w)];
                for (s in stores) params.push((macro w).field(s.name));
                EReturn(ENew('bitecs.gen.${ctx.name}'.asTypePath(), params).at()).at();
            }
        }:Function));
        mIterator.isBound = true;

        var mKeyValIter = Member.method('keyValueIterator', ({
            args: [{ name: 'w', type: worldType }],
            expr: macro return new bitecs.Query.EntityValueIterator(iterator(w))
        }:Function));
        mKeyValIter.isBound = true;

        var mOn = Member.method('on', ({
            args: [{ name: 'w', type: worldType }],
            expr: macro return new $helperTp(w, (this:$selfCt))
        }:Function));
        mOn.isBound = true;

        var mFirst = Member.method('first', ({
            args: [{ name: 'w', type: worldType }],
            expr: macro return new $firstHelperTp(w, (this:$selfCt))
        }:Function));
        mFirst.isBound = true;

        var mEntered = Member.method('enteredQuery', ({
            args: [],
            expr: macro return bitecs.Bitecs.enterQuery(this)
        }:Function));
        mEntered.isBound = true;
        var mExited = Member.method('exitedQuery', ({
            args: [],
            expr: macro return bitecs.Bitecs.exitQuery(this)
        }:Function));
        mExited.isBound = true;

        var mGetLength = Member.method('getLength', ({
            args: [{ name: 'w', type: worldType }],
            expr: macro return this(w).length
        }:Function));
        mGetLength.isBound = true;

        var mEntities = Member.method('entities', ({
            args: [{ name: 'w', type: worldType }],
            expr: macro return this(w)
        }:Function));
        mEntities.isBound = true;

        var queryWrapperTd:TypeDefinition = {
            pack: ['bitecs', 'gen'],
            name: ctx.name + 'Wrapper',
            pos: ctx.pos,
            kind: TDAbstract(queryType, [queryType]),
            fields: [mNew, mInit, mIterator, mKeyValIter, mOn, mFirst, mEntered, mExited, mGetLength, mEntities],
            meta: [{ name: ':bitecs.comps', pos: ctx.pos, params: stores.map(s -> s.compExactName.resolve()) }]
        };
        // trace(new haxe.macro.Printer().printTypeDefinition(queryWrapperTd));

        var mhNew = Member.method('new', ({
            args: [{ name: 'w', type: macro:T }, { name: 'q' }],
            params: [{ name: 'T', constraints: [worldType] }],
            expr: macro {
                this = { w: w, q: q };
                null;
            }
        }:Function));
        mhNew.isBound = true;
        var mhIter = Member.method('iterator', ({ args: [], expr: macro return this.q.iterator(this.w) }:Function));
        mhIter.isBound = true;
        var mhKeyIter = Member.method('keyValueIterator', ({ args: [], expr: macro return this.q.keyValueIterator(this.w) }:Function));
        mhKeyIter.isBound = true;

        var queryWrapperHelperTd:TypeDefinition = {
            pack: ['bitecs', 'gen'],
            name: ctx.name + 'Helper',
            pos: ctx.pos,
            kind: TDAbstract(macro:{w:$worldType, q:$selfCt}),
            fields: [mhNew, mhIter, mhKeyIter]
        }
        // trace(new haxe.macro.Printer().printTypeDefinition(queryWrapperHelperTd));

        var mfhIter = Member.method('iterator', ({
            args: [],
            expr: macro return {
                final iter = this.q.iterator(this.w);
                if (iter.length > 0) iter.length = 1;
                iter;
            }
        }:Function));
        mfhIter.isBound = true;
        var mfhKeyIter = Member.method('keyValueIterator', ({
            args: [],
            expr: macro return {
                final iter = this.q.keyValueIterator(this.w);
                if (iter.length > 0) @:privateAccess iter.iter.length = 1;
                iter;
            }
        }:Function));
        mfhKeyIter.isBound = true;

        var queryWrapperFirstHelperTd:TypeDefinition = {
            pack: ['bitecs', 'gen'],
            name: ctx.name + 'FirstHelper',
            pos: ctx.pos,
            kind: TDAbstract(macro:{w:$worldType, q:$selfCt}),
            fields: [mhNew, mfhIter, mfhKeyIter]
        }
        // trace(new haxe.macro.Printer().printTypeDefinition(queryWrapperFirstHelperTd));

        Context.defineType(queryWrapperTd);
        Context.defineType(queryWrapperHelperTd);
        Context.defineType(queryWrapperFirstHelperTd);
    }

}

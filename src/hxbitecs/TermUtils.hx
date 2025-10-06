package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

using Lambda;

/**
 * Information about a single component term.
 */
typedef TermInfo = {

    name:String,
    componentType:Type

}

/**
 * Complete information about parsed query terms.
 */
typedef QueryTermInfo = {

    // All unique components collected from the query terms
    allComponents:Array<TermInfo>,
    // The parsed query terms as expressions for bitECS
    queryExprs:Array<Expr>,
    // Unique identifier based on query structure
    structureId:String

}

/**
 * Parse query terms from a type parameter (used by HxQuery and other generic builds).
 *
 * @param worldType The world type containing component definitions
 * @param termsType The terms type (must be TInst with KExpr containing array of terms)
 * @param allowOperators Whether to allow query operators (Or, And, Not, etc.)
 * @return Parsed query term information including components and expressions
 */
function parseTerms(worldType:Type, termsType:Type, allowOperators:Bool = true):QueryTermInfo {
    var termExprs = getTermExpressions(termsType);
    return parseTermsInternal(worldType, termExprs, allowOperators);
}

/**
 * Parse query terms from an expression (used by Hx.query() and Hx.entity()).
 *
 * @param worldType The world type containing component definitions
 * @param termsExpr The terms expression (must be an array literal)
 * @param allowOperators Whether to allow query operators (Or, And, Not, etc.)
 * @return Parsed query term information including components and expressions
 */
function parseTermsFromExpr(worldType:Type, termsExpr:Expr, allowOperators:Bool = true):QueryTermInfo {
    var termExprs = getTermExpressionsFromExpr(termsExpr);
    return parseTermsInternal(worldType, termExprs, allowOperators);
}

function parseTermsInternal(worldType:Type, termExprs:Array<Expr>, allowOperators:Bool):QueryTermInfo {
    var allComponents:Array<TermInfo> = [];
    var queryExprs:Array<Expr> = [];

    for (expr in termExprs) {
        if (allowOperators) {
            var parsed = parseQueryTerm(worldType, expr, allComponents, true);
            queryExprs.push(parsed);
        } else {
            // Simple terms only - no operators allowed
            switch expr.expr {
                case EConst(CIdent(componentName)):
                    collectComponent(worldType, componentName, allComponents);
                    queryExprs.push(macro world.$componentName);
                case _:
                    Context.error('EntityAccessor only supports simple component names, not operators: ${expr.expr}', expr.pos);
            }
        }
    }

    var structureId = generateStructureId(termExprs, !allowOperators);

    return {
        allComponents: allComponents,
        queryExprs: queryExprs,
        structureId: structureId
    };
}

function getTermExpressions(terms:Type):Array<Expr> {
    return switch terms {
        case TInst(_.get().kind => KExpr({ expr: EArrayDecl(values) }), _):
            values;
        case _:
            Context.error('Expected TInst(KExpr(EArrayDecl())) for terms, got: $terms', Context.currentPos());
    }
}

function getTermExpressionsFromExpr(termsExpr:Expr):Array<Expr> {
    return switch termsExpr.expr {
        case EArrayDecl(values):
            values;
        case _:
            Context.error('Expected array literal for query terms, got: ${termsExpr.expr}', termsExpr.pos);
    }
}

/**
 * Recursively parse a single query term, handling both simple components and operators.
 *
 * This function processes query terms and determines which components should be collected
 * based on whether they appear in positive or negative contexts:
 * - Positive operators (Or, And, Any, All): Components are collected for entity wrappers
 * - Negative operators (Not, None): Components are NOT collected (entity doesn't have them)
 *
 * @param worldType The world type for resolving component types
 * @param expr The expression to parse
 * @param allComponents Accumulator for collected component information
 * @param shouldCollect Whether components in this term should be collected
 * @return The transformed expression for bitECS query
 */
function parseQueryTerm(worldType:Type, expr:Expr, allComponents:Array<TermInfo>, shouldCollect:Bool):Expr {
    return switch expr.expr {
        // Simple component reference: pos, vel, health
        case EConst(CIdent(componentName)):
            if (shouldCollect) {
                collectComponent(worldType, componentName, allComponents);
            }
            macro world.$componentName;

        // Operator calls: Or(pos, vel), Not(health), And(pos, vel)
        case ECall({ expr: EConst(CIdent(op)) }, args) if (isQueryOperator(op)):
            // Determine if components inside this operator should be collected
            var collectChildren = switch op {
                case "Not" | "None": false; // Do NOT collect components in negative operators
                case "Or" | "And" | "Any" | "All": true; // DO collect in positive operators
                case _: true;
            };

            var parsedArgs = [];
            for (arg in args) {
                parsedArgs.push(parseQueryTerm(worldType, arg, allComponents, collectChildren));
            }
            var opExpr = switch op {
                case "Or": macro bitecs.Bitecs.Or;
                case "And": macro bitecs.Bitecs.And;
                case "Not": macro bitecs.Bitecs.Not;
                case "Any": macro bitecs.Bitecs.Any;
                case "All": macro bitecs.Bitecs.All;
                case "None": macro bitecs.Bitecs.None;
                case _: Context.error('Unsupported query operator: $op', expr.pos);
            }
            { expr: ECall(opExpr, parsedArgs), pos: expr.pos };

        case _:
            Context.error('Unsupported query term: ${expr.expr}', expr.pos);
    }
}

function isQueryOperator(op:String):Bool {
    return switch op {
        case "Or" | "And" | "Not" | "Any" | "All" | "None": true;
        case _: false;
    }
}

function collectComponent(worldType:Type, componentName:String, allComponents:Array<TermInfo>):Void {
    // Check if component already collected
    for (comp in allComponents) {
        if (comp.name == componentName) return;
    }
    var componentType = getWorldComponentType(worldType, componentName);
    allComponents.push({
        name: componentName,
        componentType: componentType
    });
}

function generateStructureId(termExprs:Array<Expr>, simple:Bool = false):String {
    var parts:Array<String> = [];

    for (expr in termExprs) {
        if (simple) {
            switch expr.expr {
                case EConst(CIdent(name)):
                    parts.push(name);
                case _:
                    parts.push('Unknown');
            }
        } else {
            parts.push(exprToIdString(expr));
        }
    }

    // Use T to separate top-level terms to avoid collisions
    // e.g., [pos, None(vel, health)] -> "posTNone_vel_health"
    //       [pos, None(vel), health] -> "posTNone_velThealth"
    return parts.join('T');
}

function exprToIdString(expr:Expr):String {
    return switch expr.expr {
        case EConst(CIdent(name)):
            name;
        case ECall({ expr: EConst(CIdent(op)) }, args):
            var argStrs = [for (arg in args) exprToIdString(arg)];
            op + '_' + argStrs.join('_');
        case _:
            'Unknown';
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

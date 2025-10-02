package hxbitecs;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;

/**
 * Debug utility for macro-generated code.
 *
 * Usage:
 * - `-D hxbitecs.debug` - Enable all debug output
 * - `-D hxbitecs.debug=MyType` - Only show debug output for types containing "MyType" (case insensitive)
 */
class MacroDebug {

    /**
     * Checks if debug output should be printed for the given type/context name.
     */
    static function shouldPrint(?name:String):Bool {
        var debugDefine = Context.definedValue("hxbitecs.debug");

        // If define not set, don't print
        if (debugDefine == null) return false;

        // If define is set but empty (just `-D hxbitecs.debug`), print everything
        if (debugDefine == "1") return true;

        // If no name provided, can't filter, so print
        if (name == null) return true;

        // Filter by case-insensitive substring match
        return name.toLowerCase().indexOf(debugDefine.toLowerCase()) >= 0;
    }

    /**
     * Print a type definition if debugging is enabled.
     */
    public static function printTypeDefinition(td:TypeDefinition, ?name:String):Void {
        var typeName = name != null ? name : td.name;
        if (shouldPrint(typeName)) {
            trace(new Printer().printTypeDefinition(td));
        }
    }

    /**
     * Print an expression if debugging is enabled.
     */
    public static function printExpr(e:Expr, ?name:String):Void {
        if (shouldPrint(name)) {
            trace(new Printer().printExpr(e));
        }
    }

    /**
     * Print a string message if debugging is enabled.
     */
    public static function print(message:String, ?name:String):Void {
        if (shouldPrint(name)) {
            Sys.println(message);
        }
    }

}
#end

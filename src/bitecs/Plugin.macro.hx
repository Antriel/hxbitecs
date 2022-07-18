package bitecs;

import haxe.macro.Type;
import bitecs.Component.ComponentDefinition;

@:persistent var componentHooks:Array<Type->ComponentDefinition->Void> = [];

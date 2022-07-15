package bitecs;

/** Takes a string, makes the first letter lowercase. **/
inline function firstToLower(s:String):String return s.substr(0, 1).toLowerCase() + s.substr(1);

/** Takes a string, makes the first letter uppercase. **/
inline function firstToUpper(s:String):String return s.substr(0, 1).toUpperCase() + s.substr(1);

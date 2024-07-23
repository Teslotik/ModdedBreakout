package blocks;

import h2d.Bitmap;

enum State {
    Loaded;
    Enabled;
    Disabled;
    Generated;
    Running;
    Finished;
}

enum abstract Priority(Int) from Int to Int {
    var Lowest = 10;
    var Low = 20;
    var Normal = 30;
    var High = 40;
    var Highest = 50;
}

enum abstract Action(Int) from Int to Int {
    var Left = 0;
    var Right = 1;
    var Interact = 2;
}

typedef Entity = {
    tag:String,
    bitmap:Bitmap,
    ?isActive:Bool,
    ?velX:Float,
    ?velY:Float,
    ?scores:Int,
    ?onInput:Entity->Action->Float->Bool,
    ?onUpdate:Float->Void,
    ?onCollide:Entity->Entity->Float->Float->Void,
    ?onDestroy:Entity->Void,
    ?custom:Map<String, Dynamic>
}

typedef Modification = {
    label:String,
    priority:Priority,
    ?onEnable:Modification->Void,
    ?onDisable:Modification->Void
}

typedef Generator = {
    priority:Priority,
    onGenerate:Void->Void
}
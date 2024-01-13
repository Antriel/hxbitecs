package cases;

class TestMemoryLeak extends Test {

    @:ignore
    public function testLeak() {
        inline function getMem():Int return js.Syntax.code('process').memoryUsage().rss;
        var memStart = getMem();
        var atHalf = 0;
        for (i in 0...15000) {
            if (i == 15000 / 2) atHalf = getMem();
            var universe = Bitecs.createUniverse();
            var world = Bitecs.createWorld(universe);
            var eid = Bitecs.addEntity(world);
            Assert.equals(0, eid);
            for (_ in 0...30) {
                var component = Bitecs.defineComponent(universe, { num: Bitecs.Types.f64 });
                Bitecs.addComponent(world, component, eid);

                var query = Bitecs.defineQuery([component]);
                Assert.same([0], query(world));
            }
        }
        var memEnd = getMem();
        inline function toMB(b:Int):String return js.Syntax.code('{0}.toFixed(2)', b / 1024 / 1024) + ' MB';
        trace('memStart: ${toMB(memStart)}, atHalf: ${toMB(atHalf)}, end: ${toMB(memEnd)}, diff: ${toMB(memEnd - atHalf)}');
    }

}

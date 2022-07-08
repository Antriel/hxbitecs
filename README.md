Haxe externs for [BitECS](https://github.com/NateTheGreatt/bitECS/) with macros sprinkled on top. Initial version of externs created using [dts2hx](https://github.com/haxiomic/dts2hx), then cleaned up and improved upon.

Work in progress.
- [ ] Reset/initialize components when adding them to an entity.
- [ ] Consider getting component stores from the query directly, instead of through the world?
- [ ] Queries should be defined in Systems, but equal queries shouldn't be defined twice. That means we will need to generate some common storage type, probably in the World.

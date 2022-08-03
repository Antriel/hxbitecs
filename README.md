Haxe externs for [BitECS](https://github.com/NateTheGreatt/bitECS/) with macros sprinkled on top. Initial version of externs created using [dts2hx](https://github.com/haxiomic/dts2hx), then cleaned up and improved upon.

Work in progress.
- [x] Create a component from class definition.
- [x] Reset/initialize components when adding them to an entity.
- [x] Abstraction over query.
- [ ] Consider getting component stores from the query directly, instead of through the world?
- [x] Add basic world-related bitECS API to `World`.
- [x] Queries should be defined in Systems, ~~but equal queries shouldn't be defined twice~~. That means we will need to generate some common storage type, probably in the World.
- [x] Support for bitECS array types.
- [ ] Support for Not queries.
- [ ] Rethink macros.
    - [x] Components – going from `TypedExpr` to `Expr` is too buggy.
    - [ ] More explicit approach for World and Systems, less typing?
    - [ ] Include the world in the queries, so we can just directly iterate them?

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HxbitECS is a Haxe wrapper for bitECS v0.4 with macro-powered enhancements. It provides type-safe, ergonomic Haxe bindings for the JavaScript bitECS Entity Component System library.

## Build Configuration

- **Tests**: `haxe test.hxml` - Compiles and runs tests to `bin/tests.js`
- **Main test runner**: `tests/TestsMain.hx`

## Architecture

### Core Structure
- **`src/bitecs/`** - Direct extern bindings to bitECS JavaScript library
- **`src/hxbitecs/`** - Haxe macro layer providing type-safe wrappers
- **`tests/`** - Comprehensive test suite organized by category:
  - `externs/` - Tests for basic extern functionality
  - `behaviors/` - Tests for bitECS behavior scenarios
  - `hardcoded/` - Manual implementations that macros should generate
  - `macros/` - Tests for macro-generated code

### Key Macro Systems
- **HxQuery** (`src/hxbitecs/HxQuery.hx`) - Generates type-safe persistent query classes (mirrors bitECS `defineQuery`)
  - Provides `query.entity(eid)` method for creating entity wrappers from queries
- **Hx** (`src/hxbitecs/Hx.hx`) - Main utility class providing:
  - `Hx.query()` - Expression macro for ad-hoc queries without registration (mirrors bitECS `query`)
  - `Hx.addComponent()` - Type-safe component initialization (mirrors bitECS `addComponent`)
  - `Hx.entity()` - Expression macro for creating entity wrappers from world and component terms
  - `Hx.get()` - Single-component accessor for simplified component access
- **HxEntity** (`src/hxbitecs/HxEntity.hx`) - Type for entity wrappers with component access
  - Supports two forms: `HxEntity<World, [terms]>` and `HxEntity<QueryType>`
  - Both forms resolve to the same underlying EntityWrapper class for type compatibility
  - Used for type annotations and function parameters
- **EntityWrapperMacro** - Creates entity wrapper types with component access for queries and entity creation
- **HxComponent** - Generates component access wrappers for individual components
- **QueryIterator** (`src/hxbitecs/QueryIterator.hx`) - Unified iterator for both persistent and ad-hoc queries
- **SoA** (`src/hxbitecs/SoA.hx`) - Helper for creating Structure of Arrays component definitions

### Macro Utilities
- **MacroUtils** - Common macro generation utilities
- **TermUtils** - Query term parsing and processing
- **EntityMacroUtils** - Entity-specific macro helpers
- **MacroDebug** - Debug logging utility with compiler define support (see Debugging Macros below)

## Testing Strategy

The test suite uses utest and is organized to validate:
1. Basic extern functionality works correctly
2. bitECS behavior matches expectations
3. Hand-coded implementations work as intended
4. Macro-generated code matches hand-coded equivalents

Current test structure includes cases for store macros, query macros, and component access patterns.

## Development Notes

- Project uses Haxe with JavaScript target (ES6)
- Dependencies managed through both npm (bitECS) and Haxe libraries (utest)
- Build outputs to `bin/` directory
- Uses macro-time code generation for type safety and ergonomics
- Targets bitECS v0.4 specifically

### Query Architecture
- **Persistent queries** (`HxQuery`): Registered once, reused across frames for performance (use `new HxQuery<World, [components]>(world)`)
- **Ad-hoc queries** (`Hx.query()`): Created inline without registration for convenience (use `Hx.query(world, [components])`)
- Both query types use the unified `QueryIterator` with optimized component store access
- Entity wrappers accept `(eid, components)` where components is an array of component stores
- Macro-generated array literals enable Haxe optimizer to hoist component access outside loops

### Entity Access Patterns
Entity wrappers provide type-safe access to components for a specific entity:

- **Creating entity wrappers**:
  - `Hx.entity(world, eid, [terms])` - Create from world and component terms
  - `query.entity(eid)` - Create from existing query (shares component stores with query)
  - Both return type `HxEntity<World, [terms]>` for the same underlying EntityWrapper class

- **Type annotations**:
  - `HxEntity<World, [terms]>` - Direct specification of world and component terms
  - `HxEntity<QueryType>` - Derive from query typedef (e.g., `typedef MyQuery = HxQuery<World, [pos, vel]>`)
  - Both forms resolve to the same EntityWrapper class, ensuring full type compatibility

- **Use cases**:
  - Function parameters: `function moveEntity(e:HxEntity<MyQuery>) { e.pos.x += 10; }`
  - Direct entity manipulation outside queries: `var e = Hx.entity(world, eid, [pos, vel]); e.pos.x = 0;`
  - Sharing component stores with queries for efficient access patterns

### API Naming Convention
All wrapper APIs use "Hx" prefix to:
- Distinguish from native bitECS (avoids import conflicts)
- Make it obvious code is using the Haxe wrapper layer
- Mirror bitECS naming (e.g., `HxQuery` mirrors `defineQuery`, `Hx.query()` mirrors `query()`)

### Query Terms vs Component Stores
- **Query terms**: Expressions passed to bitECS query including operators (Or, Not, None, And, Any, All)
  - Example: `[pos, None(vel, health)]` - three terms, one with negative operator
  - Sent to bitECS to determine which entities match the query
- **Component stores**: Actual data arrays that entity wrappers can access
  - Only components the entity *has* or *might have* are included
  - Components in `Not()` or `None()` are excluded (entity doesn't have them)
  - Components in `Or()`, `And()`, `Any()`, `All()` are included (entity has or might have them)
  - Example: `[pos, None(vel, health)]` → only `pos` store passed to wrapper
  - Example: `[pos, None(vel), health]` → `pos` and `health` stores passed to wrapper
- **TermUtils.parseQueryTerm()**: Handles collection logic with `shouldCollect` parameter
  - Recursively traverses query terms to build both queryExprs and allComponents
  - Negative operators (`Not`, `None`) set `shouldCollect=false` for their children
  - Positive operators (`Or`, `And`, `Any`, `All`) set `shouldCollect=true` for their children

### Debugging Macros
The `MacroDebug` utility (`src/hxbitecs/MacroDebug.hx`) provides controlled debug output for macro-generated code:
- **Usage in code**: Use `MacroDebug.printTypeDefinition(td, name)`, `MacroDebug.printExpr(e, name)`, or `MacroDebug.print(msg, name)`
- **Enable all debug output**: `haxe build.hxml -D hxbitecs.debug`
- **Filter by type name**: `haxe build.hxml -D hxbitecs.debug=MyType` (case insensitive substring match)
- All macro debug logging should use `MacroDebug` instead of direct `trace()` or `Sys.println()` calls
- When adding new macros or debugging existing ones, use `MacroDebug` for consistent, controllable output

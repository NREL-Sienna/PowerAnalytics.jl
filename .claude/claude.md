# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# PowerAnalytics.jl - Project Guide

> **Development Guidelines:** Always load [Sienna.md](./Sienna.md) development preferences, style conventions, and best practices for projects using Sienna. Before running tests confirm that the [Sienna.md](./Sienna.md) file has been read.

## Package Role

PowerAnalytics.jl provides analytic routines for post-processing power system simulation results in the Sienna ecosystem, primarily `PowerSimulations.SimulationResults` and `ProblemResults` objects. It turns raw optimization output into aggregated, categorized time-series metrics (generation, load, cost, curtailment, capacity factor, etc.) and feeds downstream visualization (PowerGraphics.jl) and reporting.

## Core Abstractions

### ComponentSelector (from PowerSystems.jl)

Selectors declaratively identify groups of components to analyze. `make_selector` builds them from a type, a filter closure, or named subselectors. PowerAnalytics re-exports and builds on `ComponentSelector`, `SingularComponentSelector`, `PluralComponentSelector` and provides built-in selectors (`all_loads`, `all_storage`, `injector_categories`, `generator_categories`, fuel-based selectors).

### Metric hierarchy (`src/metrics.jl`)

```
Metric
├── TimedMetric
│   ├── ComponentSelectorTimedMetric
│   │   └── ComponentTimedMetric        # per-component time series over a selector
│   ├── SystemTimedMetric               # system-wide time series
│   └── CustomTimedMetric
└── TimelessMetric
    └── ResultsTimelessMetric           # scalar results stats (objective, solve time)
```

`compute(metric, results; ...)` is the dispatch core. Metrics carry a `component_agg_fn` and `time_agg_fn` (e.g. `mean`, `weighted_mean`, `unweighted_sum`); use `rebuild_metric`, `with_component_agg_fn`, `with_time_agg_fn` to derive variants and `compose_metrics` to combine them. Results are `DataFrame`s with a `DATETIME_COL` and column metadata (`is_col_meta`, `set_col_meta!`, `AGG_META_KEY`).

### Submodules

- `Selectors` — selector construction surface (`src/builtin_component_selectors.jl`)
- `Metrics` — built-in `calc_*` metric constants (`src/builtin_metrics.jl`)

## Source Layout (`src/`)

- **PowerAnalytics.jl**: module entry point, exports, include order
- **definitions.jl**: supported variable/parameter constants, slack/load renaming maps, `GENERATOR_MAPPING_FILE`

Legacy ("Old PowerAnalytics"):

- **get_data.jl**: `get_generation_data`, `get_load_data`, `get_service_data`, `categorize_data`
- **fuel_results.jl**: fuel-category aggregation, `make_fuel_dictionary`

New framework:

- **input_utils.jl**: results loading, `create_problem_results_dict`, generator-mapping parsing
- **output_utils.jl**: DataFrame column-metadata helpers, time-series accessors
- **metrics.jl**: `Metric` types, `compute`, `compute_all`, `aggregate_time`, `compose_metrics`
- **builtin_component_selectors.jl**: `Selectors` submodule, fuel/category selectors
- **builtin_metrics.jl**: `Metrics` submodule, `calc_*` constants

## Dependencies

- **PowerSimulations.jl**: source of `SimulationResults`/`ProblemResults` and variable/parameter keys
- **PowerSystems.jl**: component data model and `ComponentSelector`
- **InfrastructureSystems.jl**: shared utilities, `IS.Results`, `@assert_op`
- **DataFrames.jl / TimeSeries.jl**: tabular and time-series result containers
- **YAML.jl**: generator-mapping file parsing
- **DataStructures.jl**: `SortedDict` for deterministic ordering

## Test Patterns

- **Location**: `test/`
- **Runner**: `julia --project=test test/runtests.jl`
- **Single file**: `julia --project=test test/runtests.jl test_metrics`
- **Test data**: uses PowerSystemCaseBuilder.jl cases and stored `test/test_results/`
- **Coverage**: selectors (`test_builtin_component_selectors.jl`), metrics (`test_builtin_metrics.jl`, `test_metrics.jl`), result sorting, input parsing

## Code Conventions

**Style Guide:** [Sienna-Platform Style Guide](https://sienna-platform.github.io/InfrastructureSystems.jl/stable/style/)

### Formatter

- **Command**: `julia --project=scripts/formatter -e 'include("scripts/formatter/formatter_code.jl")'`

### Key Rules

- **Constructors**: use `function Foo()` not `Foo() = ...`
- **Asserts**: prefer `InfrastructureSystems.@assert_op` over `@assert`
- **Globals**: UPPER_CASE for constants
- **Exports**: all exports in main module file (`src/PowerAnalytics.jl`)
- **Comments**: complete sentences, describe why not how
- **Include order**: legacy files load before new-framework files — respect it when adding definitions

## Documentation Practices

**Framework:** [Diataxis](https://diataxis.fr/)
**Sienna Guide:** [Documentation Best Practices](https://sienna-platform.github.io/InfrastructureSystems.jl/stable/docs_best_practices/explanation/)

Docs under `docs/src/` follow Diataxis: `tutorials/` (Literate.jl workflow walkthroughs), `how_to_guides/`, `explanation/`, `reference/` (`public.md` uses `@autodocs` with `Public=true`, plus `internal.md` and `developer_guidelines.md`). Docstrings use `DocStringExtensions.TYPEDSIGNATURES`; add "See also" links for multiple-dispatch siblings.

## Common Tasks

```bash
# Develop locally
julia --project=test -e 'using Pkg; Pkg.develop(path=".")'

# Run tests
julia --project=test test/runtests.jl

# Build documentation
julia --project=docs docs/make.jl

# Format code
julia --project=scripts/formatter -e 'include("scripts/formatter/formatter_code.jl")'

# Instantiate test environment
julia --project=test -e 'using Pkg; Pkg.instantiate()'
```

## Contribution Workflow

- **Main branch**: `main`
- **Branch naming**: `feature/description` or `fix/description`
- Create branch → follow style guide → run formatter → ensure tests pass → submit PR

## AI Agent Guidance

### Domain Knowledge

- A `ComponentSelector` is a *query*, not a materialized set — it is resolved against a `System`/`Results` at `compute` time
- Metric results are `DataFrame`s; the datetime column (`DATETIME_COL`) and aggregation metadata are carried in column/table metadata, not separate arguments
- `component_agg_fn` aggregates across components within a selector; `time_agg_fn` aggregates across the time dimension — they are orthogonal
- Generator categorization is driven by `deps/generator_mapping.yaml`; fuel/category selectors derive from it
- Legacy `get_*_data` API and the new `Metric`/`compute` framework coexist; prefer the new framework for new functionality

### When Modifying Code

- Read existing patterns first; match the metric/selector construction idioms in `builtin_metrics.jl` / `builtin_component_selectors.jl`
- Use multiple dispatch on the `Metric`/selector type hierarchy — never `isa`/`<:` branching in function bodies
- Changes affect downstream consumers (PowerGraphics.jl, user reporting) — preserve DataFrame column conventions and metadata keys
- Fail fast with actionable errors (see `NoResultError`) rather than returning silently wrong aggregates
- Run the formatter and the full test suite before considering work complete

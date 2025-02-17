# Public API Reference

## `ComponentSelector`
PowerAnalytics depends heavily on the `ComponentSelector` feature of PowerSystems.jl. `ComponentSelector` documentation can be found [here](https://nrel-sienna.github.io/PowerSystems.jl/stable/api/public/#InfrastructureSystems.ComponentSelector).

## Input Utilities
```@autodocs
Modules = [PowerAnalytics]
Pages   = ["input_utils.jl"]
Order = [:module, :type, :function, :macro]
Private = false
```

## Metric Interface
```@docs
Metric
TimedMetric
TimelessMetric
ComponentSelectorTimedMetric
```
```@autodocs
Modules = [PowerAnalytics]
Pages   = ["metrics.jl"]
Order = [:module, :type, :function, :macro]
Private = false
Filter = t -> !(t in [Metric, TimedMetric, TimelessMetric, ComponentSelectorTimedMetric, unweighted_sum, weighted_mean])
```

## Post-Metric Utilities
These are functions that can be called on the specially formatted `DataFrame`s that [`Metric`](@ref)s produce.
```@autodocs
Modules = [PowerAnalytics]
Pages   = ["output_utils.jl"]
Order = [:module, :type, :function, :macro]
Private = false
```

## Miscellaneous
```@docs
unweighted_sum
weighted_mean
```
```@autodocs
Modules = [PowerAnalytics]
Order = [:constant]
Private = false
```

## Built-in Selectors
### Selector Utilities
```@docs
parse_generator_categories
parse_generator_mapping_file
parse_injector_categories
```
### `Selectors` Submodule
```@autodocs
Modules = [PowerAnalytics.Selectors]
Private = false
```

## Built-in Metrics
### `Metrics` Submodule
```@autodocs
Modules = [PowerAnalytics.Metrics]
Private = false
```

## Old PowerAnalytics
This interface predates the `1.0` version and will [eventually](https://github.com/NREL-Sienna/PowerAnalytics.jl/issues/28) be deprecated.
```@autodocs
Modules = [PowerAnalytics]
Pages   = ["get_data.jl", "fuel_results.jl"]
Order = [:module, :type, :function, :macro, :constant]
Private = false
```

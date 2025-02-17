# TYPE DEFINITIONS
"""
A PowerAnalytics `Metric` specifies how to compute a useful quantity, like active power or
curtailment, from a set of results. Many but not all metrics require a `ComponentSelector`
to specify which available components of the system the quantity should be computed on, and
many but not all `Metric`s return time series results. In addition to how to compute the
output -- which may be as simple as looking up a variable or parameter in the results but
may involve actual computation -- `Metric`s encapsulate default component-wise and time-wise
aggregation behaviors. Metrics can be "called" like functions. PowerAnalytics provides a
library of pre-built metrics, [`PowerAnalytics.Metrics`](@ref); users may also build their
own.

# Examples

Given a `SimulationProblemResults` `results`:
```julia
using PowerSystems
using PowerAnalytics
using PowerAnalytics.Metrics

# Call the built-in `Metric` `calc_active_power` on a `ComponentSelector` to get a
# `DataFrame` of results, where the columns are the groups in the `ComponentSelector` and
# the rows are time:
calc_active_power(make_selector(RenewableDispatch), results)

# Call the built-in `Metric` `calc_system_slack_up`, which refers to the whole system so
# doesn't need a `ComponentSelector`:
calc_system_slack_up(results)
```
"""
abstract type Metric end

"""
[`Metric`](@ref)s that return time series.
"""
abstract type TimedMetric <: Metric end

"""
[`Metric`](@ref)s that do not return time series.
"""
abstract type TimelessMetric <: Metric end

"""
[`TimedMetric`](@ref)s defined in terms of a `ComponentSelector`.
"""
abstract type ComponentSelectorTimedMetric <: TimedMetric end

# STRUCT DEFINITIONS
"""
A [`ComponentSelectorTimedMetric`](@ref) implemented by evaluating a function on each
`Component`.

# Arguments

  - `name::String`: the name of the `Metric`
  - `eval_fn`: a function with signature `(::IS.Results, ::Component;
    start_time::Union{Nothing, DateTime}, len::Union{Int, Nothing})` that returns a
    `DataFrame` representing the results for that `Component`
  - `component_agg_fn`: optional, a function to aggregate results between
    `Component`s/`ComponentSelector`s, defaults to `sum`
  - `time_agg_fn`: optional, a function to aggregate results across time, defaults to `sum`
  - `component_meta_agg_fn`: optional, a function to aggregate metadata across components,
    defaults to `sum`
  - `time_meta_agg_fn`: optional, a function to aggregate metadata across time, defaults to
    `sum`
  - `eval_zero`: optional and rarely filled in, specifies what to do in the case where there
    are no components to contribute to a particular group; defaults to `nothing`, in which
    case the data is filled in from the identity element of `component_agg_fn`
"""
@kwdef struct ComponentTimedMetric <: ComponentSelectorTimedMetric
    name::String
    eval_fn::Function
    component_agg_fn::Function = sum
    time_agg_fn::Function = sum
    component_meta_agg_fn::Function = sum
    time_meta_agg_fn::Function = sum
    eval_zero::Union{Nothing, Function} = nothing
end
# TODO test component_meta_agg_fn, time_meta_agg_fn, eval_zero if keeping them

# TODO test CustomTimedMetric
"""
A [`ComponentSelectorTimedMetric`](@ref) implemented without drilling down to the base
`Component`s, just calls the `eval_fn` directly on the `ComponentSelector`.

# Arguments

  - `name::String`: the name of the `Metric`
  - `eval_fn`: a function with signature `(::IS.Results, ::Union{ComponentSelector,
    Component}; start_time::Union{Nothing, DateTime}, len::Union{Int, Nothing})` that
    returns a `DataFrame` representing the results for that `Component`
  - `time_agg_fn`: optional, a function to aggregate results across time, defaults to `sum`
  - `time_meta_agg_fn`: optional, a function to aggregate metadata across time, defaults to
    `sum`
"""
@kwdef struct CustomTimedMetric <: ComponentSelectorTimedMetric
    name::String
    eval_fn::Function
    time_agg_fn::Function = sum
    time_meta_agg_fn::Function = sum
end

"""
A [`TimedMetric`](@ref) defined on a `System`.

# Arguments

 - `name::String`: the name of the `Metric`
 - `eval_fn`: a function with signature `(::IS.Results; start_time::Union{Nothing,
   DateTime}, len::Union{Int, Nothing})` that returns a `DataFrame` representing the results
 - `time_agg_fn`: optional, a function to aggregate results across time, defaults to `sum`
 - `time_meta_agg_fn`: optional, a function to aggregate metadata across time, defaults to
   `sum`
"""
@kwdef struct SystemTimedMetric <: TimedMetric
    name::String
    eval_fn::Function
    time_agg_fn::Function = sum
    time_meta_agg_fn::Function = sum
end

"""
A [`TimelessMetric`](@ref) with a single value per `IS.Results` instance.

# Arguments

  - `name::String`: the name of the `Metric`
  - `eval_fn`: a function with signature `(::IS.Results,)` that returns a `DataFrame`
    representing the results
"""
@kwdef struct ResultsTimelessMetric <: TimelessMetric
    name::String
    eval_fn::Function
end

"""
Signifies that the metric does not have a result for the
`Component`/`ComponentSelector`/etc. on which it is being called.
"""
struct NoResultError <: Exception
    msg::AbstractString
end

# Override these if you define Metric subtypes with different implementations
get_name(m::Metric) = m.name
get_eval_fn(m::Metric) = m.eval_fn
get_time_agg_fn(m::TimedMetric) = m.time_agg_fn
get_component_agg_fn(m::ComponentTimedMetric) = m.component_agg_fn
get_time_meta_agg_fn(m::TimedMetric) = m.time_meta_agg_fn
get_component_meta_agg_fn(m::ComponentTimedMetric) = m.component_meta_agg_fn
get_eval_zero(m::ComponentTimedMetric) = m.eval_zero

"""
Returns a `Metric` identical to the input `metric` except with the changes to its
fields specified in the keyword arguments.

# Examples
Make a variant of `calc_active_power` that averages across components rather than summing:
```julia
using PowerAnalytics.Metrics
calc_active_power_mean = rebuild_metric(calc_active_power; component_agg_fn = mean)
# (now calc_active_power_mean works as a standalone, callable metric)
```
"""
function rebuild_metric(metric::T; kwargs...) where {T <: Metric}
    metric_data = Dict(key => getfield(metric, key) for key in fieldnames(typeof(metric)))
    merge!(metric_data, kwargs)
    return T(; metric_data...)  # NOTE this works because all the `Metric` structs have @kwdef
end

"""
Canonical way to represent a `(Metric, ComponentSelector)` or `(Metric, Component)` pair as
a string.
"""
metric_selector_to_string(m::Metric, e::Union{ComponentSelector, Component}) =
    get_name(m) * COMPONENT_NAME_DELIMITER * get_name(e)

# COMPUTE() AND HELPERS
# Validation and metadata management helper function for various compute methods
function _compute_meta_timed!(val, metric, results)
    (DATETIME_COL in names(val)) || throw(
        ArgumentError(
            "Result get_eval_fn(metric) did not include a $DATETIME_COL column"),
    )
    set_col_meta!(val, DATETIME_COL)
    _compute_meta_generic!(val, metric, results)
end

function _compute_meta_generic!(val, metric, results)
    metadata!(val, "title", get_name(metric); style = :note)
    metadata!(val, "metric", metric; style = :note)
    metadata!(val, "results", results; style = :note)
    colmetadata!(
        val,
        findfirst(!=(DATETIME_COL), names(val)),
        "metric",
        metric;
        style = :note,
    )
end

# Helper function to call eval_fn and set the appropriate metadata
function _compute_component_timed_helper(metric::ComponentSelectorTimedMetric,
    results::IS.Results,
    comp::Union{Component, ComponentSelector};
    kwargs...)
    val = get_eval_fn(metric)(results, comp; kwargs...)
    _compute_meta_timed!(val, metric, results)
    colmetadata!(val, 2, "components", [comp]; style = :note)
    return val
end

"""
Compute the given metric on the given component within the given set of results, returning a
`DataFrame` with a `DateTime` column and a data column labeled with the component's name.

# Arguments
 - `metric::ComponentTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `comp::Component`: the component on which to compute the metric
 - `start_time::Union{Nothing, DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
compute(metric::ComponentTimedMetric, results::IS.Results, comp::Component; kwargs...) =
    _compute_component_timed_helper(metric, results, comp; kwargs...)

"""
Compute the given metric on the given component within the given set of results, returning a
`DataFrame` with a `DateTime` column and a data column labeled with the component's name.
Exclude components marked as not available.

# Arguments
 - `metric::CustomTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `comp::Component`: the component on which to compute the metric
 - `start_time::Union{Nothing, DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
compute(metric::CustomTimedMetric, results::IS.Results,
    comp::Union{Component, ComponentSelector};
    kwargs...) =
    _compute_component_timed_helper(metric, results, comp; kwargs...)

"""
Compute the given metric on the `System` associated with the given set of results, returning
a `DataFrame` with a `DateTime` column and a data column.

# Arguments
 - `metric::SystemTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `start_time::Union{Nothing, DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
function compute(metric::SystemTimedMetric, results::IS.Results; kwargs...)
    val = get_eval_fn(metric)(results; kwargs...)
    _compute_meta_timed!(val, metric, results)
    return val
end

"""
Compute the given metric on the given set of results, returning a `DataFrame` with a single
cell. Exclude components marked as not available.

# Arguments
 - `metric::ResultsTimelessMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
"""
function compute(metric::ResultsTimelessMetric, results::IS.Results)
    val = DataFrame(RESULTS_COL => [get_eval_fn(metric)(results)])
    _compute_meta_generic!(val, metric, results)
    return val
end

"Convenience method for `compute_all`; returns `compute(metric, results)`"
compute(metric::ResultsTimelessMetric, results::IS.Results, selector::Nothing) =
    compute(metric, results)

"Convenience method for `compute_all`; returns `compute(metric, results; kwargs...)`"
compute(metric::SystemTimedMetric, results::IS.Results, selector::Nothing; kwargs...) =
    compute(metric, results; kwargs...)

function _compute_one(metric::ComponentTimedMetric, results::IS.Results,
    selector::ComponentSelector; kwargs...)
    # TODO incorporate allow_missing
    agg_fn = get_component_agg_fn(metric)
    meta_agg_fn = get_component_meta_agg_fn(metric)
    components = get_components(selector, results)
    vals = [
        compute(metric, results, com; kwargs...) for
        com in components
    ]
    if length(vals) == 0
        if !isnothing(get_eval_zero(metric))
            result = get_eval_zero(metric)(results; kwargs...)
        else
            time_col = Vector{Union{Missing, DateTime}}([missing])
            data_col = agg_fn(Vector{Float64}())
            new_agg_meta = nothing
            result = DataFrame(DATETIME_COL => time_col, get_name(selector) => data_col)
        end
    else
        time_col = _extract_common_time(vals...)
        data_vecs = [get_data_vec(sub) for sub in _broadcast_time.(vals, Ref(time_col))]
        agg_metas = get_agg_meta.(vals)
        is_agg_meta = !all(isnothing.(agg_metas))
        data_col = is_agg_meta ? agg_fn(data_vecs, agg_metas) : agg_fn(data_vecs)
        new_agg_meta = is_agg_meta ? meta_agg_fn(agg_metas) : nothing
        result = DataFrame(DATETIME_COL => time_col, get_name(selector) => data_col)
        isnothing(new_agg_meta) || set_agg_meta!(result, new_agg_meta)
    end

    _compute_meta_timed!(result, metric, results)
    colmetadata!(result, 2, "components", components; style = :note)
    colmetadata!(result, 2, "ComponentSelector", selector; style = :note)
    return result
end

"""
Compute the given metric on the groups of the given `ComponentSelector` within the given set
of results, returning a `DataFrame` with a `DateTime` column and a data column for each
group. Exclude components marked as not available.

# Arguments
 - `metric::ComponentTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `selector::ComponentSelector`: the `ComponentSelector` on whose subselectors to compute
   the metric
 - `start_time::Union{Nothing, DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
function compute(metric::ComponentTimedMetric, results::IS.Results,
    selector::ComponentSelector; kwargs...)
    subents = get_groups(selector, results)
    subcomputations = [_compute_one(metric, results, sub; kwargs...) for sub in subents]
    return hcat_timed_dfs(subcomputations...)
end

# COMPUTE_ALL()
_is_single_group(selector::ComponentSelector, results::IS.Results) =
    length(get_groups(selector, results)) == 1
_is_single_group(selector, results::IS.Results) = true

# The core of compute_all, shared between the timed and timeless versions
function _common_compute_all(results, metrics, selectors, col_names; kwargs)
    isnothing(selectors) && (selectors = fill(nothing, length(metrics)))
    (selectors isa Vector) || (selectors = repeat([selectors], length(metrics)))
    isnothing(col_names) && (col_names = fill(nothing, length(metrics)))

    length(selectors) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(selectors)) selectors"))
    length(col_names) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(col_names)) names"))
    all(_is_single_group.(selectors, Ref(results))) || throw(
        ArgumentError("Not all selectors have exactly one group"))

    # For each triplet, do the computation, then rename the data column to the given name or
    # construct our own name
    return [
        let
            computed = compute(metric, results, selector; kwargs...)
            old_name = first(get_data_cols(computed))
            new_name =
                isnothing(name) ? metric_selector_to_string(metric, selector) : name
            DataFrames.rename(computed, old_name => new_name)
        end
        for (metric, selector, name) in zip(metrics, selectors, col_names)
    ]
end

"""
For each `(metric, selector, col_name)` tuple in `zip(metrics, selectors, col_names)`, call
[`compute`](@ref) and collect the results in a `DataFrame` with a single `DateTime` column.
All selectors must yield exactly one group.

# Arguments
 - `results::IS.Results`: the results from which to fetch data
 - `metrics::Vector{<:TimedMetric}`: the metrics to compute
 - `selectors`: either a scalar or vector of `Nothing`/`Component`/`ComponentSelector`: the
   selectors on which to compute the metrics, or nothing for system/results metrics;
   broadcast if scalar
 - `col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing`: a vector
   of names for the columns of ouput data. Entries of `nothing` default to the result of
   [`metric_selector_to_string`](@ref); `names = nothing` is equivalent to an entire vector
   of `nothing`
 - `kwargs...`: pass through to each [`compute`](@ref) call
"""
compute_all(results::IS.Results,
    metrics::Vector{<:TimedMetric},
    selectors::Union{Nothing, Component, ComponentSelector, Vector} = nothing,
    col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing;
    kwargs...,
) = hcat_timed_dfs(_common_compute_all(results, metrics, selectors, col_names; kwargs)...)

"""
For each (metric, col_name) tuple in `zip(metrics, col_names)`, call [`compute`](@ref) and
collect the results in a `DataFrame`.

# Arguments
 - `results::IS.Results`: the results from which to fetch data
 - `metrics::Vector{<:TimelessMetric}`: the metrics to compute
 - `selectors`: either a scalar or vector of `Nothing`/`Component`/`ComponentSelector`: the
   selectors on which to compute the metrics, or nothing for system/results metrics;
   broadcast if scalar
 - `col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing`: a vector
   of names for the columns of ouput data. Entries of `nothing` default to the result of
   [`metric_selector_to_string`](@ref); `names = nothing` is equivalent to an entire vector of
   `nothing`
   - `kwargs...`: pass through to each [`compute`](@ref) call
"""
compute_all(results::IS.Results, metrics::Vector{<:TimelessMetric},
    selectors::Union{Nothing, Component, ComponentSelector, Vector} = nothing,
    col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing;
    kwargs...,
) = hcat(_common_compute_all(results, metrics, selectors, col_names; kwargs)...)

const ComputationTuple =
    Tuple{<:T, Any, Any} where {T <: Union{TimedMetric, TimelessMetric}}
"""
For each (metric, selector, col_name) tuple in `computations`, call [`compute`](@ref) and
collect the results in a `DataFrame` with a single `DateTime` column. All selectors must
yield exactly one group.

# Arguments
 - `results::IS.Results`: the results from which to fetch data
 - `computations::(Tuple{<:T, Any, Any} where T <: Union{TimedMetric, TimelessMetric})...`:
   a list of the computations to perform, where each element is a `(metric, selector,
   col_name)`` where `metric` is the metric to compute, `selector` is the ComponentSelector
   on which to compute the metric or `nothing` if not relevant, and `col_name` is the name
   for the output column of data or nothing to use the default
   - `kwargs...`: pass through to each [`compute`](@ref) call
"""
compute_all(results::IS.Results, computations::ComputationTuple...; kwargs...) =
    compute_all(results, collect.(zip(computations...))...; kwargs...)

# HIGHER-LEVEL METRIC FUNCTIONS
function _common_compose_metrics(res, sel, reduce_fn, metrics, output_col_name; kwargs...)
    col_names = string.(range(1, length(metrics)))
    sub_results = compute_all(res, collect(metrics), sel, col_names; kwargs...)
    result = DataFrames.transform(sub_results, col_names => reduce_fn => output_col_name)
    (DATETIME_COL in names(result)) && return result[!, [DATETIME_COL, output_col_name]]
    return first(result[!, output_col_name])  # eval_fn of timeless metrics returns scalar
end

"""
Given a list of metrics and a function that applies to their results to produce one result,
create a new metric that computes the sub-metrics and applies the function to produce its
own result.

# Arguments
 - `name::String`: the name of the new [`Metric`](@ref)
 - `reduce_fn`: a function that takes one value from each of the input `Metric`s and returns
   a single value that will be the result of this `Metric`. "Value" means a vector (not a
   `DataFrame`) in the case of [`TimedMetric`](@ref)s and a scalar for
   [`TimelessMetric`](@ref)s.
 - `metrics`: the input `Metric`s. It is currently not possible to combine `TimedMetric`s
   with `TimelessMetric`s, though it is possible to combine `ComponentSelectorTimedMetric`s
   with `SystemTimedMetric`s.

# Examples

This is the implementation of the built-in metric [`calc_load_from_storage`](@ref), which
computes the preexisting built-in metrics [`calc_active_power_in`](@ref) and
[`calc_active_power_out`](@ref) and combines them by subtraction:
```julia
const calc_load_from_storage = compose_metrics(
    "LoadFromStorage",
    (-),
    calc_active_power_in, calc_active_power_out)
```
"""
function compose_metrics end  # For the unified docstring

compose_metrics(
    name::String,
    reduce_fn,
    metrics::ComponentSelectorTimedMetric...,
) = CustomTimedMetric(; name = name,
    eval_fn = (res::IS.Results, sel::Union{Component, ComponentSelector}; kwargs...) ->
        _common_compose_metrics(
            res,
            sel,
            reduce_fn,
            metrics,
            get_name(sel);
            kwargs...,
        ),
)

compose_metrics(
    name::String,
    reduce_fn,
    metrics::SystemTimedMetric...) = SystemTimedMetric(; name = name,
    eval_fn = (res::IS.Results; kwargs...) ->
        _common_compose_metrics(
            res,
            nothing,
            reduce_fn,
            metrics,
            SYSTEM_COL;
            kwargs...,
        ),
)

compose_metrics(
    name::String,
    reduce_fn,
    metrics::ResultsTimelessMetric...) = ResultsTimelessMetric(; name = name,
    eval_fn = (
        res::IS.Results ->
            _common_compose_metrics(
                res,
                nothing,
                reduce_fn,
                metrics,
                RESULTS_COL,
            )
    ),
)

# Create a ComponentSelectorTimedMetric that wraps a SystemTimedMetric, disregarding the ComponentSelector
component_selector_metric_from_system_metric(in_metric::SystemTimedMetric) =
    CustomTimedMetric(;
        name = get_name(in_metric),
        eval_fn = (res::IS.Results, comp::Union{Component, ComponentSelector}; kwargs...) ->
            compute(in_metric, res; kwargs...))

# This one only gets triggered when we have at least one ComponentSelectorTimedMetric *and*
# at least one SystemTimedMetric, in which case the behavior is to treat the
# SystemTimedMetrics as if they applied to the selector
function compose_metrics(
    name::String,
    reduce_fn,
    metrics::Union{ComponentSelectorTimedMetric, SystemTimedMetric}...)
    wrapped_metrics = [
        (m isa SystemTimedMetric) ? component_selector_metric_from_system_metric(m) : m
        for
        m in metrics
    ]
    return compose_metrics(name, reduce_fn, wrapped_metrics...)
end

# FUNCTOR INTERFACE TO COMPUTE()
(metric::ComponentSelectorTimedMetric)(selector::ComponentSelector,
    results::IS.Results; kwargs...) =
    compute(metric, results, selector; kwargs...)

(metric::Union{SystemTimedMetric, ResultsTimelessMetric})(results::IS.Results; kwargs...) =
    compute(metric, results; kwargs...)

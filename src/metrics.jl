# TYPE DEFINITIONS
# TODO there is probably a more principled way of structuring this Metric type hierarchy -- maybe parameterization?
"The basic type for all `Metrics`."
abstract type Metric end

"Time series `Metrics`."
abstract type TimedMetric <: Metric end

"Scalar-in-time `Metrics`."
abstract type TimelessMetric <: Metric end

"Time series `Metrics` defined on `ComponentSelector`s."
abstract type ComponentSelectorTimedMetric <: TimedMetric end

# STRUCT DEFINITIONS
"""
`ComponentSelectorTimedMetrics` implemented by evaluating a function on each `Component`.

# Arguments
 - `name::String`: the name of the `Metric`
 - `eval_fn`: a callable with signature
   `(::IS.Results, ::Component; start_time::Union{Nothing, DateTime}, len::Union{Int, Nothing})`
   that returns a DataFrame representing the results for that `Component`
 - `component_agg_fn`: optional, a callable to aggregate results between
   `Component`s/`ComponentSelector`s, defaults to `sum`
 - `time_agg_fn`: optional, a callable to aggregate results across time, defaults to `sum`
    
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
`ComponentSelectorTimedMetrics` implemented without drilling down to the base `Component`s,
just call the `eval_fn` directly.

# Arguments
 - `name::String`: the name of the `Metric`
 - `eval_fn`: a callable with signature `(::IS.Results, ::Union{ComponentSelector,
   Component}; start_time::Union{Nothing, DateTime}, len::Union{Int, Nothing})` that returns a
   DataFrame representing the results for that `Component`
 - `time_agg_fn`: optional, a callable to aggregate results across time, defaults to `sum`
"""
@kwdef struct CustomTimedMetric <: ComponentSelectorTimedMetric
    name::String
    eval_fn::Function
    time_agg_fn::Function = sum
    time_meta_agg_fn::Function = sum
end

"""
Time series `Metrics` defined on `Systems`.

# Arguments
 - `name::String`: the name of the `Metric`
 - `eval_fn`: a callable with signature
   `(::IS.Results; start_time::Union{Nothing, DateTime}, len::Union{Int, Nothing})` that returns a
   DataFrame representing the results
 - `time_agg_fn`: optional, a callable to aggregate results across time, defaults to `sum`
"""
@kwdef struct SystemTimedMetric <: TimedMetric
    name::String
    eval_fn::Function
    time_agg_fn::Function = sum
    time_meta_agg_fn::Function = sum
end

"""
Timeless Metrics with a single value per `IS.Results` instance

# Arguments
    - `name::String`: the name of the `Metric`
    - `eval_fn`: a callable with signature `(::IS.Results,)` that returns a `DataFrame`
      representing the results
"""
@kwdef struct ResultsTimelessMetric <: TimelessMetric
    name::String
    eval_fn::Function
end

"""
The metric does not have a result for the `Component`/`ComponentSelector`/etc. on which it
is being called.
"""
struct NoResultError <: Exception
    msg::AbstractString
end

# SMALL FUNCTIONS
# Override these if you define Metric subtypes with different implementations
get_name(m::Metric) = m.name
get_time_agg_fn(m::TimedMetric) = m.time_agg_fn
# TODO is there a naming convention for this kind of function?
"Returns a `Metric` identical to the input except with the given `time_agg_fn`"
with_time_agg_fn(m::T, time_agg_fn) where {T <: ComponentSelectorTimedMetric} =
    T(;
        name = m.name,
        eval_fn = m.eval_fn,
        time_agg_fn = time_agg_fn,
    )

get_component_agg_fn(m::ComponentTimedMetric) = m.component_agg_fn
"Returns a `Metric` identical to the input except with the given `component_agg_fn`"
with_component_agg_fn(m::ComponentTimedMetric, component_agg_fn) =
    ComponentTimedMetric(;
        name = m.name,
        eval_fn = m.eval_fn,
        component_agg_fn = component_agg_fn,
    )

get_time_meta_agg_fn(m::TimedMetric) = m.time_meta_agg_fn
"Returns a `Metric` identical to the input except with the given `time_meta_agg_fn`"
with_time_meta_agg_fn(m::T, time_meta_agg_fn) where {T <: ComponentSelectorTimedMetric} =
    T(m.name, m.eval_fn; time_meta_agg_fn = time_meta_agg_fn)

get_component_meta_agg_fn(m::ComponentTimedMetric) = m.component_meta_agg_fn
"Returns a `Metric` identical to the input except with the given `component_meta_agg_fn`"
with_component_meta_agg_fn(m::ComponentTimedMetric, component_meta_agg_fn) =
    ComponentTimedMetric(;
        name = m.name,
        eval_fn = m.eval_fn,
        component_meta_agg_fn = component_meta_agg_fn,
    )

"""
Canonical way to represent a `(Metric, ComponentSelector)` or `(Metric, Component)` pair as
a string.
"""
metric_selector_to_string(m::Metric, e::Union{ComponentSelector, Component}) =
    get_name(m) * COMPONENT_NAME_DELIMITER * get_name(e)

# COMPUTE() AND HELPERS
# Validation and metadata management helper function for various compute methods
function _compute_meta_timed!(val, metric, results)
    (DATETIME_COL in names(val)) || throw(ArgumentError(
        "Result metric.eval_fn did not include a $DATETIME_COL column"))
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
    val = metric.eval_fn(results, comp; kwargs...)
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
a `DataFrame` with a `DateTime` column and a data column. Exclude components marked as not
available.

# Arguments
 - `metric::SystemTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `start_time::Union{Nothing, DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
function compute(metric::SystemTimedMetric, results::IS.Results; kwargs...)
    val = metric.eval_fn(results; kwargs...)
    _compute_meta_timed!(val, metric, results)
    return val
end

"""
Compute the given metric on the given set of results, returning a DataFrame with a single
cell. Exclude components marked as not available.

# Arguments
 - `metric::ResultsTimelessMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
"""
function compute(metric::ResultsTimelessMetric, results::IS.Results)
    val = DataFrame(RESULTS_COL => [metric.eval_fn(results)])
    _compute_meta_generic!(val, metric, results)
    return val
end

"""
Compute the given metric on the given set of results, returning a `DataFrame` with a single
cell; takes a `Nothing` where the `ComponentSelectorTimedMetric` method of this function
would take a `Component`/`ComponentSelector` for convenience. Exclude components marked as
not available.
"""
compute(metric::ResultsTimelessMetric, results::IS.Results, selector::Nothing) =
    compute(metric, results)

"""
Compute the given metric on the `System` associated with the given set of results, returning
a `DataFrame` with a `DateTime` column and a data column; takes a `Nothing` where the
`ComponentSelectorTimedMetric` method of this function would take a
`Component`/`ComponentSelector` for convenience. Exclude components marked as not available.
"""
compute(metric::SystemTimedMetric, results::IS.Results, selector::Nothing; kwargs...) =
    compute(metric, results; kwargs...)

function _compute_one(metric::ComponentTimedMetric, results::IS.Results,
    selector::ComponentSelector; kwargs...)
    # TODO incorporate allow_missing
    agg_fn = get_component_agg_fn(metric)
    meta_agg_fn = get_component_meta_agg_fn(metric)
    components = get_components(
        selector,
        PowerSimulations.get_system(results);
        filterby = get_available,
    )
    vals = [
        compute(metric, results, com; kwargs...) for
        com in components
    ]
    if length(vals) == 0
        if metric.eval_zero !== nothing
            result = metric.eval_zero(results; kwargs...)
        else
            time_col = Vector{Union{Missing, DateTime}}([missing])
            data_col = agg_fn(Vector{Float64}())
            new_agg_meta = nothing
            result = DataFrame(DATETIME_COL => time_col, get_name(selector) => data_col)
        end
    else
        time_col = _extract_common_time(vals...)
        data_vecs = [data_vec(sub) for sub in _broadcast_time.(vals, Ref(time_col))]
        agg_metas = get_agg_meta.(vals)
        is_agg_meta = !all(agg_metas .=== nothing)
        data_col = is_agg_meta ? agg_fn(data_vecs, agg_metas) : agg_fn(data_vecs)
        new_agg_meta = is_agg_meta ? meta_agg_fn(agg_metas) : nothing
        result = DataFrame(DATETIME_COL => time_col, get_name(selector) => data_col)
        (new_agg_meta === nothing) || set_agg_meta!(result, new_agg_meta)
    end

    _compute_meta_timed!(result, metric, results)
    colmetadata!(result, 2, "components", components; style = :note)
    colmetadata!(result, 2, "ComponentSelector", selector; style = :note)
    return result
end

# TODO update docstring
"""
Compute the given metric on the groups of the given `ComponentSelector` within the given set
of results, returning a `DataFrame` with a `DateTime` column and a data column for each
group. Exclude components marked as not available.

# Arguments
 - `metric::ComponentSelectorTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `selector::ComponentSelector`: the `ComponentSelector` on whose subselectors to compute
   the metric
 - `start_time::Union{Nothing, DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
function compute(metric::ComponentTimedMetric, results::IS.Results,
    selector::ComponentSelector; kwargs...)
    subents = PSY.get_groups(
        selector,
        PowerSimulations.get_system(results);
        filterby = get_available,
    )
    subcomputations = [_compute_one(metric, results, sub; kwargs...) for sub in subents]
    return hcat_timed(subcomputations...)
end

# COMPUTE_ALL()
# The core of compute_all, shared between the timed and timeless versions
function _common_compute_all(results, metrics, selectors, col_names; kwargs)
    (selectors === nothing) && (selectors = fill(nothing, length(metrics)))
    (selectors isa Vector) || (selectors = repeat([selectors], length(metrics)))
    (col_names === nothing) && (col_names = fill(nothing, length(metrics)))

    length(selectors) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(selectors)) selectors"))
    length(col_names) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(col_names)) names"))

    # For each triplet, do the computation, then rename the data column to the given name or
    # construct our own name
    return [
        let
            computed = compute(metric, results, selector; kwargs...)
            old_name = first(data_cols(computed))
            new_name =
                (name === nothing) ? metric_selector_to_string(metric, selector) : name
            DataFrames.rename(computed, old_name => new_name)
        end
        for (metric, selector, name) in zip(metrics, selectors, col_names)
    ]
end

"""
For each `(metric, selector, col_name)` tuple in `zip(metrics, selectors, col_names)`, call
[`compute`](@ref) and collect the results in a `DataFrame` with a single `DateTime` column.

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
) = hcat_timed(_common_compute_all(results, metrics, selectors, col_names; kwargs)...)

"""
For each (metric, col_name) tuple in `zip(metrics, col_names)`, call [`compute`](@ref) and
collect the results in a DataFrame.

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

ComputationTuple = Tuple{<:T, Any, Any} where {T <: Union{TimedMetric, TimelessMetric}}
"""
For each (metric, selector, col_name) tuple in `computations`, call [`compute`](@ref) and
collect the results in a DataFrame with a single `DateTime` column.

# Arguments
 - `results::IS.Results`: the results from which to fetch data
 - `computations::(Tuple{<:T, Any, Any} where T <: Union{TimedMetric, TimelessMetric})...`:
   a list of the computations to perform, where each element is a (metric, selector,
   col_name) where metric is the metric to compute, selector is the ComponentSelector on
   which to compute the metric or nothing if not relevant, and col_name is the name for the
   output column of data or nothing to use the default
   - `kwargs...`: pass through to each [`compute`](@ref) call
"""
compute_all(results::IS.Results, computations::ComputationTuple...; kwargs...) =
    compute_all(results, collect.(zip(computations...))...; kwargs...)

function _common_compose_metrics(res, ent, reduce_fn, metrics, output_col_name; kwargs...)
    col_names = string.(range(1, length(metrics)))
    sub_results = compute_all(res, collect(metrics), ent, col_names; kwargs...)
    result = DataFrames.transform(sub_results, col_names => reduce_fn => output_col_name)
    (DATETIME_COL in names(result)) && return result[!, [DATETIME_COL, output_col_name]]
    return first(result[!, output_col_name])  # eval_fn of timeless metrics returns scalar
end

# HIGHER-LEVEL METRIC FUNCTIONS
"""
Given a list of metrics and a function that applies to their results to produce one result,
create a new metric that computes the sub-metrics and applies the function to produce its
own result.

# Arguments
 - `name::String`: the name of the new `Metric`
 - `reduce_fn`: a callable that takes one value from each of the input `Metric`s and returns
   a single value that will be the result of this `Metric`. "Value" means a vector (not a
   `DataFrame`) in the case of `TimedMetrics` and a scalar for `TimelessMetrics`.
 - `metrics`: the input `Metrics`. It is currently not possible to combine `TimedMetrics`
   with `TimelessMetrics`, though it is possible to combine `ComponentSelectorTimedMetrics`
   with `SystemTimedMetrics`.
"""
function compose_metrics end  # For the unified docstring

compose_metrics(
    name::String,
    reduce_fn,
    metrics::ComponentSelectorTimedMetric...,
) = CustomTimedMetric(; name = name,
    eval_fn = (res::IS.Results, ent::Union{Component, ComponentSelector}; kwargs...) ->
        _common_compose_metrics(
            res,
            ent,
            reduce_fn,
            metrics,
            get_name(ent);
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

# TODO there is probably a more principled way of structuring this Metric type hierarchy -- maybe parameterization?
"The basic type for all `Metrics`."
abstract type Metric end

"Time series `Metrics`."
abstract type TimedMetric <: Metric end

"Scalar-in-time `Metrics`."
abstract type TimelessMetric <: Metric end

"Time series `Metrics` defined on `ComponentSelector`s."
abstract type ComponentSelectorTimedMetric <: TimedMetric end

"""
`ComponentSelectorTimedMetrics` implemented by evaluating a function on each `Component`.

# Arguments
 - `name::String`: the name of the `Metric`
 - `description::String`: a description of the `Metric`
 - `eval_fn`: a callable with signature
   `(::IS.Results, ::Component, ::Union{Nothing, Dates.DateTime}, ::Union{Int, Nothing})`
   that returns a DataFrame representing the results for that `Component`
 - `component_agg_fn`: optional, a callable to aggregate results between
   `Component`s/`ComponentSelector`s, defaults to `sum`
 - `time_agg_fn`: optional, a callable to aggregate results across time, defaults to `sum`
    
"""
struct ComponentTimedMetric <: ComponentSelectorTimedMetric
    name::String
    description::String
    eval_fn::Any
    component_agg_fn::Any
    time_agg_fn::Any
    component_meta_agg_fn::Any
    time_meta_agg_fn::Any
    eval_zero::Any
end

# TODO test component_meta_agg_fn, time_meta_agg_fn, eval_zero if keeping them
ComponentTimedMetric(
    name::String,
    description::String,
    eval_fn::Function;
    component_agg_fn = sum,
    time_agg_fn = sum,
    component_meta_agg_fn = sum,
    time_meta_agg_fn = sum,
    eval_zero = nothing,
) = ComponentTimedMetric(
    name,
    description,
    eval_fn,
    component_agg_fn,
    time_agg_fn,
    component_meta_agg_fn,
    time_meta_agg_fn,
    eval_zero,
)

# TODO test CustomTimedMetric
"""
`ComponentSelectorTimedMetrics` implemented without drilling down to the base `Component`s,
just call the `eval_fn` directly.

# Arguments
 - `name::String`: the name of the `Metric`
 - `description::String`: a description of the `Metric`
 - `eval_fn`: a callable with signature `(::IS.Results, ::Union{ComponentSelector,
   Component}, ::Union{Nothing, Dates.DateTime}, ::Union{Int, Nothing})` that returns a
   DataFrame representing the results for that `Component`
 - `time_agg_fn`: optional, a callable to aggregate results across time, defaults to `sum`
"""
struct CustomTimedMetric <: ComponentSelectorTimedMetric
    name::String
    description::String
    eval_fn::Any
    time_agg_fn::Any
    time_meta_agg_fn::Any
end

CustomTimedMetric(
    name::String,
    description::String,
    eval_fn::Function;
    time_agg_fn = sum,
    time_meta_agg_fn = sum,
) =
    CustomTimedMetric(name, description, eval_fn, time_agg_fn, time_meta_agg_fn)

"""
Time series `Metrics` defined on `Systems`.

# Arguments
 - `name::String`: the name of the `Metric`
 - `description::String`: a description of the `Metric`
 - `eval_fn`: a callable with signature
   `(::IS.Results, ::Union{Nothing, Dates.DateTime}, ::Union{Int, Nothing})` that returns a
   DataFrame representing the results
 - `time_agg_fn`: optional, a callable to aggregate results across time, defaults to `sum`
"""
struct SystemTimedMetric <: TimedMetric
    name::String
    description::String
    eval_fn::Any
    time_agg_fn::Any
    time_meta_agg_fn::Any
end

SystemTimedMetric(
    name::String,
    description::String,
    eval_fn::Function;
    time_agg_fn = sum,
    time_meta_agg_fn = sum,
) =
    SystemTimedMetric(name, description, eval_fn, time_agg_fn, time_meta_agg_fn)

"""
Timeless Metrics with a single value per `IS.Results` instance

# Arguments
    - `name::String`: the name of the `Metric`
    - `description::String`: a description of the `Metric`
    - `eval_fn`: a callable with signature `(::IS.Results,)` that returns a `DataFrame`
      representing the results
"""
struct ResultsTimelessMetric <: TimelessMetric
    name::String
    description::String
    eval_fn::Function
end

"""
The metric does not have a result for the `Component`/`ComponentSelector`/etc. on which it
is being called.
"""
struct NoResultError <: Exception
    msg::AbstractString
end

# TODO remove :DateTime hardcoding in PowerSimulations
"Name of the column that represents the time axis in computed DataFrames"
const DATETIME_COL::String = "DateTime"

"""
Column metadata key whose value signifies whether the column is metadata. Metadata columns
are excluded from `data_cols` and similar and can be used to represent things like a time
aggregation.
"""
const META_COL_KEY::String = "meta_col"

"Name of a column that represents whole-of-`System` data"
const SYSTEM_COL::String = "System"

"Name of a column that represents whole-of-`Results` data"
const RESULTS_COL::String = "Results"

"""
Column metadata key whose value, if any, is additional information to be passed to
aggregation functions. Values of `nothing` are equivalent to absence of the entry.
"""
const AGG_META_KEY::String = "agg_meta"

# Override these if you define Metric subtypes with different implementations
get_name(m::Metric) = m.name
get_description(m::Metric) = m.description
get_time_agg_fn(m::TimedMetric) = m.time_agg_fn
# TODO is there a naming convention for this kind of function?
"Returns a `Metric` identical to the input except with the given `time_agg_fn`"
with_time_agg_fn(m::T, time_agg_fn) where {T <: ComponentSelectorTimedMetric} =
    T(m.name, m.description, m.eval_fn; time_agg_fn = time_agg_fn)

get_component_agg_fn(m::ComponentTimedMetric) = m.component_agg_fn
"Returns a `Metric` identical to the input except with the given `component_agg_fn`"
with_component_agg_fn(m::ComponentTimedMetric, component_agg_fn) =
    ComponentTimedMetric(
        m.name,
        m.description,
        m.eval_fn;
        component_agg_fn = component_agg_fn,
    )

get_time_meta_agg_fn(m::TimedMetric) = m.time_meta_agg_fn
"Returns a `Metric` identical to the input except with the given `time_meta_agg_fn`"
with_time_meta_agg_fn(m::T, time_meta_agg_fn) where {T <: ComponentSelectorTimedMetric} =
    T(m.name, m.description, m.eval_fn; time_meta_agg_fn = time_meta_agg_fn)

get_component_meta_agg_fn(m::ComponentTimedMetric) = m.component_meta_agg_fn
"Returns a `Metric` identical to the input except with the given `component_meta_agg_fn`"
with_component_meta_agg_fn(m::ComponentTimedMetric, component_meta_agg_fn) =
    ComponentTimedMetric(
        m.name,
        m.description,
        m.eval_fn;
        component_meta_agg_fn = component_meta_agg_fn,
    )

"""
Canonical way to represent a `(Metric, ComponentSelector)` or `(Metric, Component)` pair as
a string.
"""
metric_selector_to_string(m::Metric, e::Union{ComponentSelector, Component}) =
    get_name(m) * NAME_DELIMETER * get_name(e)

"Check whether a column is metadata"
is_col_meta(df, colname) = get(colmetadata(df, colname), META_COL_KEY, false)

"Mark a column as metadata"
set_col_meta!(df, colname, val = true) =
    colmetadata!(df, colname, META_COL_KEY, val; style = :note)

"Get the column's aggregation metadata; return `nothing` if there is none."
get_agg_meta(df, colname) = get(colmetadata(df, colname), AGG_META_KEY, nothing)

"Get the single data column's aggregation metadata; error on multiple data columns."
function get_agg_meta(df)
    my_data_cols = data_cols(df)
    (length(my_data_cols) == 1) && return get_agg_meta(df, first(my_data_cols))
    throw(
        ArgumentError(
            "DataFrame has $(size(the_data, 2)) columns of data, must specify a column name",
        ),
    )
end

"Set the column's aggregation metadata."
set_agg_meta!(df, colname, val) =
    colmetadata!(df, colname, AGG_META_KEY, val; style = :note)

"Set the single data column's aggregation metadata; error on multiple data columns."
function set_agg_meta!(df, val)
    my_data_cols = data_cols(df)
    (length(my_data_cols) == 1) && return set_agg_meta!(df, first(my_data_cols), val)
    throw(
        ArgumentError(
            "DataFrame has $(size(the_data, 2)) columns of data, must specify a column name",
        ),
    )
end

# TODO test that mutating the selection mutates the original
"Select the `DateTime` column of the `DataFrame` as a one-column `DataFrame` without copying."
time_df(df::DataFrames.AbstractDataFrame) =
    DataFrames.select(df, DATETIME_COL; copycols = false)

"Select the `DateTime` column of the `DataFrame` as a `Vector` without copying."
time_vec(df::DataFrames.AbstractDataFrame) = df[!, DATETIME_COL]

"""
Select the names of the data columns of the `DataFrame`, i.e., those that are not `DateTime`
and not metadata.
"""
data_cols(df::DataFrames.AbstractDataFrame) =
    filter(
        (
            colname ->
                (colname != DATETIME_COL) &&
                    !is_col_meta(df, colname)
        ),
        names(df))

"Select the data columns of the `DataFrame` as a `DataFrame` without copying."
data_df(df::DataFrames.AbstractDataFrame) =
    DataFrames.select(df, data_cols(df); copycols = false)

"Select the data column of the `DataFrame` as a vector without copying, errors if more than one."
function data_vec(df::DataFrames.AbstractDataFrame)
    the_data = data_df(df)
    (size(the_data, 2) > 1) && throw(
        ArgumentError(
            "DataFrame has $(size(the_data, 2)) columns of data, consider using data_mat",
        ),
    )
    return the_data[!, 1]
end

"Select the data columns of the `DataFrame` as a `Matrix` with copying."
data_mat(df::DataFrames.AbstractDataFrame) = Matrix(data_df(df))

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
function _compute_selector_timed_helper(metric::ComponentSelectorTimedMetric,
    results::IS.Results,
    comp::Union{Component, ComponentSelector};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing)
    val = metric.eval_fn(results, comp, start_time, len)
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
 - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
compute(metric::ComponentTimedMetric, results::IS.Results, comp::Component;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing) =
    _compute_selector_timed_helper(metric, results, comp; start_time, len)

"""
Compute the given metric on the given component within the given set of results, returning a
`DataFrame` with a `DateTime` column and a data column labeled with the component's name.

# Arguments
 - `metric::CustomTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `comp::Component`: the component on which to compute the metric
 - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
compute(metric::CustomTimedMetric, results::IS.Results,
    comp::Union{Component, ComponentSelector};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing) =
    _compute_selector_timed_helper(metric, results, comp; start_time, len)

"""
Compute the given metric on the `System` associated with the given set of results, returning
a `DataFrame` with a `DateTime` column and a data column.

# Arguments
 - `metric::SystemTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
function compute(metric::SystemTimedMetric, results::IS.Results;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing)
    val = metric.eval_fn(results, start_time, len)
    _compute_meta_timed!(val, metric, results)
    return val
end

"""
Compute the given metric on the given set of results, returning a DataFrame with a single
cell.

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
cell; takes a `Nothing` where the `ComponentSelectorTimedMetric` method of this function would take a
`Component`/`ComponentSelector` for convenience
"""
compute(metric::ResultsTimelessMetric, results::IS.Results, selector::Nothing) =
    compute(metric, results)

"""
Compute the given metric on the `System` associated with the given set of results, returning
a `DataFrame` with a `DateTime` column and a data column; takes a `Nothing` where the
`ComponentSelectorTimedMetric` method of this function would take a `Component`/`ComponentSelector` for
convenience
"""
compute(metric::SystemTimedMetric, results::IS.Results, selector::Nothing;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing) = compute(metric, results;
    start_time = start_time, len = len)

# TODO test allow_missing behavior
function _extract_common_time(dfs::DataFrames.AbstractDataFrame...;
    allow_missing = true, ex_fn::Function = time_vec)
    time_cols = ex_fn.(dfs)
    allow_missing || !any([any(ismissing.(ex_fn(tc))) for tc in time_cols]) ||
        throw(ErrorException("Missing time columns"))
    # Candidate time column is the one with the most non-missing values
    time_col = argmax(x -> count(!ismissing, Array(x)), time_cols)
    # Other time columns must either be the same or [nothing]
    # TODO come up with a more informative error here
    all([
        isequal(sub, time_col) ||
            (all(ismissing.(Array(sub))) && size(sub, 1) == 1) for sub in time_cols
    ]) ||
        throw(ErrorException("Mismatched time columns"))
    return time_col
end

# TODO test
function _broadcast_time(data_cols, time_col; allow_unitary = true)
    size(data_cols, 1) == size(time_col, 1) && return data_cols
    (allow_unitary && size(data_cols, 1) == 1) ||
        throw(ErrorException("Individual data column does not match aggregate time column"))
    return repeat(data_cols, size(time_col, 1))  # Preserves metadata
end

# NOTE this really makes the case for a dedicated type for time-indexed dataframes, then
# this would just be another hcat method to multiply dispatch
"""
If the time axes match across all the `DataFrames`, horizontally concatenate them and remove
the duplicate time axes. If not, throw an error
"""
function hcat_timed(vals::DataFrame...)  # TODO incorporate allow_missing
    time_col = _extract_common_time(vals...; ex_fn = time_df)
    broadcasted_vals = [data_df(sub) for sub in _broadcast_time.(vals, Ref(time_col))]
    return hcat(time_col, broadcasted_vals...)
end

"""
Compute the given `Metric` on the given `ComponentSelector` within the given set of results, aggregating
across all the components in the `ComponentSelector` if necessary and returning a `DataFrame` with a
`DateTime` column and a data column labeled with the `ComponentSelector`'s name.

# Arguments
 - `metric::ComponentTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `selector::ComponentSelector`: the `ComponentSelector` on which to compute the metric
 - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
function compute(metric::ComponentTimedMetric, results::IS.Results,
    selector::ComponentSelector;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing)
    # TODO incorporate allow_missing
    agg_fn = get_component_agg_fn(metric)
    meta_agg_fn = get_component_meta_agg_fn(metric)
    components = get_components(selector, PowerSimulations.get_system(results))
    vals = [
        compute(metric, results, com; start_time = start_time, len = len) for
        com in components
    ]
    if length(vals) == 0
        if metric.eval_zero !== nothing
            result = metric.eval_zero(results, start_time, len)
        else
            time_col = Vector{Union{Missing, Dates.DateTime}}([missing])
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

# TODO these are currently necessary because eval_fn is supposed to take start_time and len
# as positional arguments and compute as kwargs; would it be better to just switch one of
# those?
"""A version of `compute` that takes positional arguments for convenience"""
compute(met, res, ent, start_time, len) =
    compute(met, res, ent; start_time = start_time, len = len)

"""A version of `compute` that takes positional arguments for convenience"""
compute(met, res, start_time, len) =
    compute(met, res; start_time = start_time, len = len)

# TODO function compute_set
"""
Compute the given metric on the subselectors of the given `ComponentSelector` within the
given set of results, returning a `DataFrame` with a `DateTime` column and a data column for
each subselector. Should be the same as calling `compute` on each subselector and
concatenating.

# Arguments
 - `metric::ComponentSelectorTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `selector::ComponentSelector`: the `ComponentSelector` on whose subselectors to compute
   the metric
 - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of steps in the resulting time series
"""
function compute_set(metric::ComponentSelectorTimedMetric, results::IS.Results,
    selector::ComponentSelector;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing)
    subents = get_subselectors(selector, PowerSimulations.get_system(results))
    subcomputations = [compute(metric, results, sub; start_time, len) for sub in subents]
    return hcat_timed(subcomputations...)
end

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
collect the results in a DataFrame with a single DateTime column.

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

# Sometimes, to construct new column names, we need to construct strings that don't appear
# as/in any other column names
function _make_unique_col_name(col_names;
    allow_substring = false, initial_try = "newcol", suffix = "!")
    col_name = initial_try
    while allow_substring ? (col_name in col_names) : any(occursin.(col_name, col_names))
        col_name *= suffix
    end
    return col_name
end

# Fetch the time_agg_fn associated with the particular column's Metric; error if no agg_fn can be determined
function _find_time_agg_fn(df, col_name, default_agg_fn)
    my_agg_fn = default_agg_fn
    col_md = colmetadata(df, col_name)
    haskey(col_md, "metric") && (my_agg_fn = get_time_agg_fn(col_md["metric"]))
    (my_agg_fn === nothing) && throw(
        ArgumentError(
            "No time aggregation function found for $col_name; specify in metric or use agg_fn kwarg $(col_md)",
        ),
    )
    return my_agg_fn
end

# Construct a pipeline that can be passed to DataFrames.combine that represents the aggregation of the given column
function _construct_aggregation(df, agg_meta_colnames, col_name, default_agg_fn)
    agg_fn = _find_time_agg_fn(df, col_name, default_agg_fn)
    if haskey(agg_meta_colnames, col_name)
        return [col_name, agg_meta_colnames[col_name]] => agg_fn => col_name
    end
    return col_name => agg_fn => col_name
end

function _construct_meta_aggregation(df, col_name, meta_colname)
    agg_fn = get_time_meta_agg_fn(colmetadata(df, col_name)["metric"])
    return meta_colname => agg_fn => meta_colname
end

"""
Given a DataFrame like that produced by [`compute_all`](@ref), group by a function of the
time axis, apply a reduction, and report the resulting aggregation indexed by the first
timestamp in each group.

# Arguments
 - `df::DataFrames.AbstractDataFrame`: the DataFrame to operate upon
 - `groupby_fn = nothing`: a callable that can be passed a DateTime; two rows will be in the
   same group iff their timestamps produce the same result under `groupby_fn`. Note that
   `groupby_fn = month` puts January 2023 and January 2024 into the same group whereas
   `groupby_fn=(x -> (year(x), month(x)))` does not.
 - `groupby_col::Union{Nothing, AbstractString, Symbol} = nothing`: specify a column name to
   report the result of `groupby_fn` in the output DataFrame, or `nothing` to not
 - `agg_fn = nothing`: by default, the aggregation function (`sum`/`mean`/etc.) is specified
   by the Metric, which is read from the metadata of each column. If this metadata isn't
   found, one can specify a default aggregation function like `sum` here; if nothing, an
   error will be thrown.
"""
function aggregate_time(
    df::DataFrames.AbstractDataFrame;
    groupby_fn = nothing,
    groupby_col::Union{Nothing, AbstractString, Symbol} = nothing,
    agg_fn = nothing)
    keep_groupby_col = (groupby_col !== nothing)
    if groupby_fn === nothing && keep_groupby_col
        throw(ArgumentError("Cannot keep the groupby column if not specifying groupby_fn"))
    end

    # Everything goes into the same group by default
    (groupby_fn === nothing) && (groupby_fn = (_ -> 0))

    # Validate or create groupby column name
    if keep_groupby_col
        (groupby_col in names(df)) &&
            throw(ArgumentError("groupby_col cannot be an existing column name of df"))
    else
        groupby_col = _make_unique_col_name(
            names(df);
            allow_substring = true,
            initial_try = "grouped",
        )
    end

    # Find all aggregation metadata
    # TODO should metadata columns be allowed to have aggregation metadata? Probably.
    agg_metas = Dict(varname => get_agg_meta(df, varname) for varname in data_cols(df))

    # Create column names for non-nothing aggregation metadata
    existing_cols = vcat(names(df), groupby_col)
    agg_meta_colnames = Dict(
        varname =>
            _make_unique_col_name(existing_cols; initial_try = varname * "_meta")
        for varname in data_cols(df) if agg_metas[varname] !== nothing)
    cols_with_agg_meta = collect(keys(agg_meta_colnames))

    # TODO currently we can only handle Vector aggregation metadata (eventually we'll
    # probably need two optional aggregation metadata fields, one for per-column data and
    # one for per-element data)
    @assert all(typeof.([agg_metas[cn] for cn in cols_with_agg_meta]) .<: Vector)
    @assert all(
        length(agg_metas[orig_name]) == length(df[!, orig_name])
        for orig_name in cols_with_agg_meta
    )

    # Add the groupby column and aggregation metadata columns
    transformed = DataFrames.transform(
        df,
        DATETIME_COL => DataFrames.ByRow(groupby_fn) => groupby_col,
    )
    for orig_name in cols_with_agg_meta
        transformed[!, agg_meta_colnames[orig_name]] = agg_metas[orig_name]
    end

    grouped = DataFrames.groupby(transformed, groupby_col)
    # For all data columns and non-special metadata columns, find the agg_fn and handle aggregation metadata
    aggregations = [
        _construct_aggregation(df, agg_meta_colnames, col_name, agg_fn)
        for col_name in names(df) if !(col_name in (groupby_col, DATETIME_COL))
    ]
    meta_aggregations = [
        _construct_meta_aggregation(df, orig_name, agg_meta_colnames[orig_name])
        for orig_name in cols_with_agg_meta
    ]
    # Take the first DateTime in each group, reduce the other columns as specified in aggregations, preserve column names
    # TODO is it okay to always just take the first timestamp, or should there be a
    # reduce_time_fn kwarg to, for instance, allow users to specify that they want the
    # midpoint timestamp?
    combined = DataFrames.combine(grouped,
        DATETIME_COL => first => DATETIME_COL,
        aggregations..., meta_aggregations...)

    # Replace the aggregation metadata
    for orig_name in cols_with_agg_meta
        set_agg_meta!(combined, orig_name, combined[!, agg_meta_colnames[orig_name]])
    end

    # Drop agg_meta columns, reorder the columns for convention
    not_index = DataFrames.Not(groupby_col, DATETIME_COL, values(agg_meta_colnames)...)
    result = DataFrames.select(combined, DATETIME_COL, groupby_col, not_index)

    set_col_meta!(result, DATETIME_COL)
    set_col_meta!(result, groupby_col)
    keep_groupby_col || (result = DataFrames.select(result, DataFrames.Not(groupby_col)))
    return result
end

function _common_compose_metrics(res, ent, reduce_fn, metrics, output_col_name; kwargs...)
    col_names = string.(range(1, length(metrics)))
    sub_results = compute_all(res, collect(metrics), ent, col_names; kwargs...)
    result = DataFrames.transform(sub_results, col_names => reduce_fn => output_col_name)
    (DATETIME_COL in names(result)) && return result[!, [DATETIME_COL, output_col_name]]
    return first(result[!, output_col_name])  # eval_fn of timeless metrics returns scalar
end

"""
Given a list of metrics and a function that applies to their results to produce one result,
create a new metric that computes the sub-metrics and applies the function to produce its
own result.

# Arguments
 - `name::String`: the name of the new `Metric`
 - `description::String`: the description of the new `Metric`
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
    description::String,
    reduce_fn,
    metrics::ComponentSelectorTimedMetric...,
) = CustomTimedMetric(name, description,
    (res::IS.Results, ent::Union{Component, ComponentSelector},
        start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) ->
        _common_compose_metrics(
            res,
            ent,
            reduce_fn,
            metrics,
            get_name(ent);
            start_time = start_time,
            len = len,
        ),
)

compose_metrics(
    name::String,
    description::String,
    reduce_fn,
    metrics::SystemTimedMetric...) = SystemTimedMetric(name, description,
    (
        res::IS.Results,
        start_time::Union{Nothing, Dates.DateTime},
        len::Union{Int, Nothing},
    ) ->
        _common_compose_metrics(
            res,
            nothing,
            reduce_fn,
            metrics,
            SYSTEM_COL;
            start_time = start_time,
            len = len,
        ),
)

compose_metrics(
    name::String,
    description::String,
    reduce_fn,
    metrics::ResultsTimelessMetric...) = ResultsTimelessMetric(name, description,
    res::IS.Results ->
        _common_compose_metrics(
            res,
            nothing,
            reduce_fn,
            metrics,
            RESULTS_COL,
        ),
)

# Create a ComponentSelectorTimedMetric that wraps a SystemTimedMetric, disregarding the ComponentSelector
component_selector_metric_from_system_metric(in_metric::SystemTimedMetric) =
    CustomTimedMetric(
        get_name(in_metric),
        get_description(in_metric),
        (res::IS.Results, comp::Union{Component, ComponentSelector},
            start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) ->
            compute(in_metric, res, start_time, len))

# This one only gets triggered when we have at least one ComponentSelectorTimedMetric *and*
# at least one SystemTimedMetric, in which case the behavior is to treat the
# SystemTimedMetrics as if they applied to the selector
function compose_metrics(
    name::String,
    description::String,
    reduce_fn,
    metrics::Union{ComponentSelectorTimedMetric, SystemTimedMetric}...)
    wrapped_metrics = [
        (m isa SystemTimedMetric) ? component_selector_metric_from_system_metric(m) : m
        for
        m in metrics
    ]
    return compose_metrics(name, description, reduce_fn, wrapped_metrics...)
end

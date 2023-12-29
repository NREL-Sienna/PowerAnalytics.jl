# TODO there is probably a more principled way of structuring this Metric type hierarchy -- maybe parameterization?
"The basic type for all Metrics."
abstract type Metric end

"Time series Metrics."
abstract type TimedMetric <: Metric end

"Scalar-in-time Metrics."
abstract type TimelessMetric <: Metric end

"Time series Metrics defined on Entities."
abstract type EntityTimedMetric <: TimedMetric end

"EntityTimedMetrics implemented by evaluating a function on each Component"
struct ComponentTimedMetric <: EntityTimedMetric
    name::String
    description::String
    eval_fn::Function
end

"Time series Metrics defined on Systems."
struct SystemTimedMetric <: TimedMetric
    name::String
    description::String
    eval_fn::Function
end

"Timeless Metrics with a single value per Results struct"
struct ResultsTimelessMetric <: TimelessMetric
    name::String
    description::String
    eval_fn::Function
end

"""
The metric does not have a result for the Component/Entity/etc. on which it is being called.
"""
struct NoResultError <: Exception
    msg::AbstractString
end

# TODO remove :DateTime hardcoding in PowerSimulations
"Name of the column that represents the time axis in computed DataFrames"
const DATETIME_COL::String = "DateTime"

"""
Column metadata key whose value signifies whether the column is metadata. Metadata columns
are excluded from data_cols and similar and can be used to represent things like a time
aggregation.
"""
const META_COL_KEY::String = "meta_col"

"Name of a column that represents whole-of-System data"
const SYSTEM_COL::String = "System"

"Name of a column that represents whole-of-Results data"
const RESULTS_COL::String = "Results"

get_name(m::Union{ComponentTimedMetric, SystemTimedMetric, ResultsTimelessMetric}) = m.name
get_description(m::Union{ComponentTimedMetric, SystemTimedMetric, ResultsTimelessMetric}) =
    m.description

"Canonical way to represent a (Metric, Entity) pair as a string."
metric_entity_to_string(m::Metric, e::Entity) =
    get_name(m) * NAME_DELIMETER * get_name(e)

"Check whether a column is metadata"
is_col_meta(df, colname) = get(colmetadata(df, colname), META_COL_KEY, false)

"Mark a column as metadata"
set_col_meta!(df, colname, val = true) =
    colmetadata!(df, colname, META_COL_KEY, val; style = :note)

# TODO test that mutating the selection mutates the original
"Select the DateTime column of the DataFrame as a one-column DataFrame without copying."
time_df(df::DataFrames.AbstractDataFrame) =
    DataFrames.select(df, DATETIME_COL; copycols = false)

"Select the DateTime column of the DataFrame as a Vector without copying."
time_vec(df::DataFrames.AbstractDataFrame) = df[!, DATETIME_COL]

"Select the data columns of the DataFrame, i.e., those that are not DateTime and not metadata"
data_cols(df::DataFrames.AbstractDataFrame) =
    filter(
        (
            colname ->
                (colname != DATETIME_COL) &&
                    !is_col_meta(df, colname)
        ),
        names(df))

"Select the data columns of the DataFrame as a DataFrame without copying."
data_df(df::DataFrames.AbstractDataFrame) =
    DataFrames.select(df, data_cols(df); copycols = false)

"Select the data column of the DataFrame as a vector without copying, errors if more than one."
function data_vec(df::DataFrames.AbstractDataFrame)
    the_data = data_df(df)
    (size(the_data, 2) > 1) && throw(
        ArgumentError(
            "DataFrame has $(size(the_data, 2)) columns of data, consider using data_mat",
        ),
    )
    return the_data[!, 1]
end

"Select the data columns of the DataFrame as a Matrix with copying."
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

"""
Compute the given metric on the given component within the given set of results, returning a
DataFrame with a DateTime column and a data column labeled with the component's name.

# Arguments
 - `metric::ComponentTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `comp::Component`: the component on which to compute the metric
 - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of points in the resulting time series
"""
function compute(metric::ComponentTimedMetric, results::IS.Results, comp::Component;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing)
    val = metric.eval_fn(results, comp, start_time, len)
    _compute_meta_timed!(val, metric, results)
    colmetadata!(val, 2, "components", [comp]; style = :note)
    return val
end

"""
Compute the given metric on the System associated with the given set of results, returning a
DataFrame with a DateTime column and a data column.

# Arguments
 - `metric::SystemTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of points in the resulting time series
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
Compute the given metric on the given set of results, returning a DataFrame with a single
cell; takes Nothing where the ComponentTimedMetric method of this function would take a
Component/Entity for convenience
"""
compute(metric::ResultsTimelessMetric, results::IS.Results, entity::Nothing) =
    compute(metric, results)

"""
Compute the given metric on the System associated with the given set of results, returning a
DataFrame with a DateTime column and a data column; takes Nothing where the
ComponentTimedMetric method of this function would take a Component/Entity for convenience
"""
compute(metric::SystemTimedMetric, results::IS.Results, entity::Nothing;
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
Horizontally concatenate the dataframes leaving one time column if the time axes all match
and throwing an error if not
"""
function hcat_timed(vals::DataFrame...)  # TODO incorporate allow_missing
    time_col = _extract_common_time(vals...; ex_fn = time_df)
    broadcasted_vals = [data_df(sub) for sub in _broadcast_time.(vals, Ref(time_col))]
    return hcat(time_col, broadcasted_vals...)
end

"""
Compute the given metric on the given entity within the given set of results, aggregating
across all the components in the entity if necessary and returning a DataFrame with a
DateTime column and a data column labeled with the entity's name.

# Arguments
 - `metric::ComponentTimedMetric`: the metric to compute
 - `results::IS.Results`: the results from which to fetch data
 - `entity::Entity`: the entity on which to compute the metric
 - `start_time::Union{Nothing, Dates.DateTime} = nothing`: the time at which the resulting
   time series should begin
 - `len::Union{Int, Nothing} = nothing`: the number of points in the resulting time series
 - `agg_fn::Function = sum`: specifies how to aggregate across the components in the entity
"""
function compute(metric::ComponentTimedMetric, results::IS.Results, entity::Entity;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing, agg_fn::Function = sum)
    # TODO incorporate allow_missing
    components = get_components(entity, PowerSimulations.get_system(results))
    vals = [
        compute(metric, results, com; start_time = start_time, len = len) for
        com in components
    ]
    if length(vals) == 0
        result = DataFrame(
            DATETIME_COL => Vector{Union{Missing, Dates.DateTime}}([missing]),
            get_name(entity) => agg_fn(Vector{Float64}()))
        set_col_meta!(result, DATETIME_COL)
        return result
    end
    time_col = _extract_common_time(vals...)
    data_col = agg_fn([data_vec(sub) for sub in _broadcast_time.(vals, Ref(time_col))])
    val = DataFrame(DATETIME_COL => time_col, get_name(entity) => data_col)

    _compute_meta_timed!(val, metric, results)
    colmetadata!(val, 2, "components", components; style = :note)
    colmetadata!(val, 2, "entity", entity; style = :note)
    return val
end

# TODO function compute_set

# The core of compute_all, shared between the timed and timeless versions
function _common_compute_all(results, metrics, entities, col_names; kwargs)
    (entities === nothing) && (entities = fill(nothing, length(metrics)))
    (col_names === nothing) && (col_names = fill(nothing, length(metrics)))

    length(entities) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(entities)) entities"))
    length(col_names) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(col_names)) names"))

    # For each triplet, do the computation, then rename the data column to the given name or
    # construct our own name
    return [
        let
            computed = compute(metric, results, entity; kwargs...)
            old_name = first(data_cols(computed))
            new_name = (name === nothing) ? metric_entity_to_string(metric, entity) : name
            DataFrames.rename(computed, old_name => new_name)
        end
        for (metric, entity, name) in zip(metrics, entities, col_names)
    ]
end

"""
For each (metric, result, entity) tuple in zip(metrics, results, entities), call
[`compute`](@ref) and collect the results in a DataFrame with a single DateTime column.

# Arguments
 - `metrics::Vector{<:TimedMetric}`: the metrics to compute
 - `results::IS.Results`: the results from which to fetch data
 - `entities::Union{Nothing, Vector{<:Union{Nothing, Entity}}} = nothing`: the entities on
   which to compute the metrics, or nothing for system/results metrics
 - `col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing`: a vector
   of names for the columns of ouput data. Entries of `nothing` default to the result of
   [`metric_entity_to_string`](@ref); `names = nothing` is equivalent to an entire vector of
   `nothing`
 - `kwargs...`: pass through to [`compute`](@ref)
"""
compute_all(results::IS.Results,
    metrics::Vector{<:TimedMetric},
    entities::Union{Nothing, Vector{<:Union{Nothing, Entity}}} = nothing,
    col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing;
    kwargs...,
) = hcat_timed(_common_compute_all(results, metrics, entities, col_names; kwargs)...)

"""
For each (metric, result, entity) tuple in zip(metrics, results, entities), call
[`compute`](@ref) and collect the results in a DataFrame.

# Arguments
 - `metrics::Vector{<:TimelessMetric}`: the metrics to compute
 - `results::IS.Results`: the results from which to fetch data
 - `entities::Union{Nothing, Vector{<:Union{Nothing, Entity}}} = nothing`: the entities on
   which to compute the metrics, or nothing for system/results metrics
 - `col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing`: a vector
   of names for the columns of ouput data. Entries of `nothing` default to the result of
   [`metric_entity_to_string`](@ref); `names = nothing` is equivalent to an entire vector of
   `nothing`
 - `kwargs...`: pass through to [`compute`](@ref)
"""
compute_all(results::IS.Results, metrics::Vector{<:TimelessMetric};
    entities::Union{Nothing, Vector{<:Union{Nothing, Entity}}} = nothing,
    col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing,
    kwargs...,
) = hcat(_common_compute_all(results, metrics, entities, col_names; kwargs)...)

# We need a temporary column name that doesn't overlap with the existing ones
function _make_groupby_col_name(col_names)
    groupby_col = "grouped"
    while groupby_col in col_names  # Worst case length(col_names) iterations
        groupby_col *= "!"
    end
    return groupby_col
end

"""
Given a DataFrame like that produced by [`compute_all`](@ref), group by a function of the
time axis, apply a reduction, and report the resulting aggregation indexed by the first
timestamp in each group.

# Arguments
 - `df::DataFrames.AbstractDataFrame`: the DataFrame to operate upon
 - `groupby_fn = nothing`: a callable that can be passed a DateTime; two rows will be in the
   same group iff their timestamps produce the same result under `groupby_fn`. Note that
   `groupby_fn=month` puts January 2023 and January 2024 into the same group whereas
   `groupby_fn=(x -> (year(x), month(x)))` does not.
 - `reduce_fn = sum`: a callable that takes a vector of data and produces a scalar of data;
   gets called for each column in each group
 - `groupby_col::Union{Nothing, AbstractString, Symbol} = nothing`: specify a column name to
   report the result of `groupby_fn` in the output DataFrame, or `nothing` to not
"""
function aggregate_time(
    df::DataFrames.AbstractDataFrame;
    groupby_fn = nothing,
    reduce_fn = sum,
    groupby_col::Union{Nothing, AbstractString, Symbol} = nothing)

    # Everything goes into the same group by default
    (groupby_fn === nothing) && (groupby_fn = (_ -> 0))

    keep_groupby_col = (groupby_col !== nothing)
    if keep_groupby_col
        (groupby_col in names(df)) &&
            throw("groupby_col cannot be an existing column name of df")
    else
        groupby_col = _make_groupby_col_name(names(df))
    end

    transformed = DataFrames.transform(
        df,
        DATETIME_COL => DataFrames.ByRow(groupby_fn) => groupby_col,
    )
    grouped = DataFrames.groupby(transformed, groupby_col)
    # Operate on all data columns and non-special metadata columns
    not_index = DataFrames.Not(groupby_col, DATETIME_COL)
    # Take the first DateTime in each group, reduce the other columns, preserve column names
    # TODO is it okay to always just take the first timestamp, or should there be a
    # reduce_time_fn kwarg to, for instance, allow users to specify that they want the
    # midpoint timestamp?
    combined = DataFrames.combine(grouped,
        DATETIME_COL => first => DATETIME_COL,
        not_index .=> reduce_fn .=> not_index)
    # Reorder the columns for convention
    result = DataFrames.select(combined, DATETIME_COL, groupby_col, not_index)

    set_col_meta!(result, DATETIME_COL)
    set_col_meta!(result, groupby_col)
    keep_groupby_col || (result = DataFrames.select(result, DataFrames.Not(groupby_col)))
    return result
end

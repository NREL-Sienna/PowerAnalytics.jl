"The basic type for all Metrics."
abstract type Metric end

"Time series Metrics defined on Entities."
abstract type EntityTimedMetric <: Metric end

"EntityTimedMetrics implemented by evaluating a function on Components"
struct ComponentTimedMetric <: EntityTimedMetric
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
Column metadata key whose value signifies whether the column is metadata (i.e.,
`is_metadata = get(colmetadata(df, colname), META_COL_KEY, false)`). Metadata columns are
excluded from data_cols and similar and can be used to represent things like a time
aggregation.
"""
const META_COL_KEY::String = "meta_col"

get_name(m::ComponentTimedMetric) = m.name
get_description(m::ComponentTimedMetric) = m.description

"Canonical way to represent a (Metric, Entity) pair as a string."
metric_entity_to_string(m::Metric, e::Entity) =
    get_name(m) * NAME_DELIMETER * get_name(e)

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
                    !get(colmetadata(df, colname), META_COL_KEY, false)
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
    (DATETIME_COL in names(val)) || throw(ArgumentError(
        "Result metric.eval_fn did not include a $DATETIME_COL column"))

    metadata!(val, "title", metric.name; style = :note)
    metadata!(val, "metric", metric; style = :note)
    metadata!(val, "results", results; style = :note)
    colmetadata!(val, DATETIME_COL, META_COL_KEY, true; style = :note)
    colmetadata!(val, 2, "components", [comp]; style = :note)
    colmetadata!(val, 2, "metric", metric; style = :note)
    return val
end

# TODO test allow_missing behavior
function _extract_common_time(dfs::Vector{<:DataFrames.AbstractDataFrame};
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
    components = get_components(entity, PowerSimulations.get_system(results))
    vals = [
        compute(metric, results, com; start_time = start_time, len = len) for
        com in components
    ]
    (length(vals) == 0) && return colmetadata(
        DataFrame(
            DATETIME_COL => Vector{Union{Missing, Dates.DateTime}}([missing]),
            get_name(entity) => agg_fn(Vector{Float64}())),
        DATETIME_COL, META_COL_KEY, true; style = :note)

    time_col = _extract_common_time(vals)
    data_col = agg_fn([data_vec(sub) for sub in _broadcast_time.(vals, Ref(time_col))])
    val = DataFrame(DATETIME_COL => time_col, get_name(entity) => data_col)

    metadata!(val, "title", metric.name; style = :note)
    metadata!(val, "metric", metric; style = :note)
    metadata!(val, "results", results; style = :note)
    colmetadata!(val, DATETIME_COL, META_COL_KEY, true; style = :note)
    colmetadata!(val, 2, "components", components; style = :note)
    colmetadata!(val, 2, "entity", entity; style = :note)
    colmetadata!(val, 2, "metric", metric; style = :note)
    return val
end

# TODO function compute_set

"""
For each (metric, result, entity) tuple in zip(metrics, results, entities), call
[`compute`](@ref) and collect the results in a DataFrame with a single DateTime column.

# Arguments
 - `metrics::Vector{<:EntityTimedMetric}`: the metrics to compute
 - `results::IS.Results`: the results from which to fetch data
 - `entities::Vector{<:Entity}`: the entities on which to compute the metrics
 - `col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing`: a vector
   of names for the columns of ouput data. Entries of `nothing` default to the result of
   [`metric_entity_to_string`](@ref); `names = nothing` is equivalent to an entire vector of
   `nothing`
 - `kwargs...`: pass through to [`compute`](@ref)
"""
function compute_all(metrics::Vector{<:EntityTimedMetric},
    results::IS.Results,
    entities::Vector{<:Entity},
    col_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing;
    kwargs...,
)
    (col_names === nothing) && (col_names = fill(nothing, length(metrics)))
    length(entities) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(entities)) entities"))
    length(col_names) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(col_names)) names"))

    vals = [
        DataFrames.rename(
            compute(metric, results, entity; kwargs...),
            get_name(entity) =>
                (name === nothing) ? metric_entity_to_string(metric, entity) : name,
        ) for (metric, entity, name) in zip(metrics, entities, col_names)
    ]

    time_col = _extract_common_time(vals; ex_fn = time_df)
    result_cols = _broadcast_time.(data_df.(vals), Ref(time_col))
    pushfirst!(result_cols, time_col)
    result = hcat(result_cols...)
    return result
end

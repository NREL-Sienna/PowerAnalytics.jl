"The basic type for all Metrics."
abstract type Metric end

"Time series Metrics defined on Entities."
abstract type EntityTimedMetric <: Metric end

struct ComponentTimedMetric <: EntityTimedMetric
    name::String
    description::String
    eval_fn::Function
end

get_name(m::ComponentTimedMetric) = m.name
get_description(m::ComponentTimedMetric) = m.description

"Select the DateTime column of the DataFrame as a one-column DataFrame."
time_df(df::DataFrames.AbstractDataFrame) = DataFrames.select(df, :DateTime)

"Select the DateTime column of the DataFrame as a Vector."
time_vec(df::DataFrames.AbstractDataFrame) = df[!, :DateTime]

"Select the non-DateTime columns of the DataFrame as a DataFrame."
data_df(df::DataFrames.AbstractDataFrame) = DataFrames.select(df, DataFrames.Not(:DateTime))

"Canonical way to represent a (Metric, Entity) pair as a string."
metric_entity_to_string(m::Metric, e::Entity) =
    get_name(m) * NAME_DELIMETER * get_name(e)

"Select the non-DateTime column of the DataFrame as a vector, errors if more than one"
function data_vec(df::DataFrames.AbstractDataFrame)
    the_data = data_df(df)
    (size(the_data, 2) > 1) && throw(
        ArgumentError(
            "DataFrame has $(size(the_data, 2)) columns of data, consider using data_mat",
        ),
    )
    return the_data[!, 1]
end

"Select the non-DateTime columns of the DataFrame as a Matrix"
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

    metadata!(val, "title", metric.name; style = :note)
    metadata!(val, "metric", metric; style = :note)
    metadata!(val, "results", results; style = :note)
    colmetadata!(val, 2, "components", [comp]; style = :note)
    colmetadata!(val, 2, "metric", metric; style = :note)
    return val
end

function _extract_common_time(dfs::Vector{<:DataFrames.AbstractDataFrame}; ex_fn = time_vec)
    time_col = ex_fn(first(dfs))
    # TODO come up with a more informative error here
    all([ex_fn(sub) == time_col for sub in dfs[2:end]]) ||
        throw(ErrorException("Mismatched time columns"))
    return time_col
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
    (length(vals) == 0) && return DataFrame()

    time_col = _extract_common_time(vals)
    data_col = agg_fn([data_vec(sub) for sub in vals])
    val = DataFrame("DateTime" => time_col, get_name(entity) => data_col)

    metadata!(val, "title", metric.name; style = :note)
    metadata!(val, "metric", metric; style = :note)
    metadata!(val, "results", results; style = :note)
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
 - `names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing`: a vector of
   names for the columns of ouput data. Entries of `nothing` default to the result of
   [`metric_entity_to_string`](@ref); `names = nothing` is equivalent to an entire vector of
   `nothing`
 - `kwargs...`: pass through to [`compute`](@ref)
"""
function compute_all(metrics::Vector{<:EntityTimedMetric},
    results::IS.Results,
    entities::Vector{<:Entity},
    names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing;
    kwargs...,
)
    (names === nothing) && (names = fill(nothing, length(metrics)))
    length(entities) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(entities)) entities"))
    length(names) == length(metrics) || throw(
        ArgumentError("Got $(length(metrics)) metrics but $(length(names)) names"))

    vals = [
        DataFrames.rename(
            compute(metric, results, entity; kwargs...),
            get_name(entity) =>
                (name === nothing) ? metric_entity_to_string(metric, entity) : name,
        ) for (metric, entity, name) in zip(metrics, entities, names)
    ]

    time_col = _extract_common_time(vals; ex_fn = time_df)
    result_cols = data_df.(vals)
    pushfirst!(result_cols, time_col)
    result = hcat(result_cols...)
    return result
end

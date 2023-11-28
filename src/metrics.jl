"The basic type for all Metrics."
abstract type Metric end

"Time series Metrics defined on Entities."
abstract type EntityTimedMetric <: Metric end

struct ComponentTimedMetric <: EntityTimedMetric
    name::String
    description::String
    eval_fn::Function
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

    metadata!(val, "title", metric.name)
    metadata!(val, "metric", metric)
    colmetadata!(val, 2, "components", [comp])
    return val
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

    time_col = vals[1][!, :DateTime]
    # TODO come up with a more informative error here
    all([sub[!, :DateTime] == time_col for sub in vals[2:end]]) ||
        throw(ErrorException("Mismatched time columns"))

    data_col = agg_fn([sub[!, 2] for sub in vals])
    val = DataFrame("DateTime" => time_col, get_name(entity) => data_col)

    metadata!(val, "title", metric.name)
    metadata!(val, "metric", metric)
    colmetadata!(val, 2, "components", components)
    colmetadata!(val, 2, "entity", entity)
    return val
end

# TODO: put make_key in PowerSimulations and refactor existing code to use it
# TODO test

"The various key entry types that can work with a System"
const SystemEntryType = Union{
    PSI.VariableType,
    PSI.ExpressionType,
}

"The various key entry types that can be used to make a PSI.OptimizationContainerKey"
const EntryType = Union{
    SystemEntryType,
    PSI.ParameterType,
    PSI.AuxVariableType,
    PSI.InitialConditionType,
}

"Create a PSI.OptimizationContainerKey from the given key entry type and component.

# Arguments
 - `entry::Type{<:EntryType}`: the key entry
 - `component` (`::Type{<:Union{Component, PSY.System}}` or `::Type{<:Component}` depending
   on the key type): the component type
"
function make_key end
make_key(entry::Type{<:PSI.VariableType}, component::Type{<:Union{Component, PSY.System}}) =
    PSI.VariableKey(entry, component)
make_key(entry::Type{<:PSI.ExpressionType}, comp::Type{<:Union{Component, PSY.System}}) =
    PSI.ExpressionKey(entry, comp)
make_key(entry::Type{<:PSI.ParameterType}, component::Type{<:Component}) =
    PSI.ParameterKey(entry, component)
make_key(entry::Type{<:PSI.AuxVariableType}, component::Type{<:Component}) =
    PSI.AuxVarKey(entry, component)
make_key(entry::Type{<:PSI.InitialConditionType}, component::Type{<:Component}) =
    PSI.ICKey(entry, component)

# TODO caching needs to happen here
# TODO test
"Given an EntryType and a Component, fetch a single column of results"
function read_component_result(res::IS.Results, entry::Type{<:EntryType}, comp::Component,
    start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing})
    key = make_key(entry, typeof(comp))
    res = first(
        values(PSI.read_results_with_keys(
                res,
                [key];
                start_time = start_time,
                len = len,
            )),
    )
    get_name(comp) in names(res) ||
        throw(
            NoResultError(
                "$(get_name(comp)) not in the results for $(PSI.encode_key_as_string(key))",
            ),
        )
    return res[!, [DATETIME_COL, get_name(comp)]]
end

# TODO caching here too
"Given an EntryType that applies to the System, fetch a single column of results"
function read_system_result(res::IS.Results, entry::Type{<:SystemEntryType},
    start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing})
    key = make_key(entry, PSY.System)
    res = first(
        values(PSI.read_results_with_keys(
                res,
                [key];
                start_time = start_time,
                len = len,
            )),
    )
    @assert size(res, 2) == 2 "Expected a time column and a data column in the results for $(PSI.encode_key_as_string(key)), got $(size(res, 2)) columns"
    @assert DATETIME_COL in names(res) "Expected a column named $DATETIME_COL in the results for $(PSI.encode_key_as_string(key)), got $(names(res))"
    # Whatever the non-time column is, rename it to something standard
    res = DataFrames.rename(res, findfirst(!=(DATETIME_COL), names(res)) => SYSTEM_COL)
    return res[!, [DATETIME_COL, SYSTEM_COL]]
end

# TODO test
"Convenience function to convert an EntryType to a function and make a ComponentTimedMetric from it"
make_component_metric_from_entry(
    name::String,
    description::String,
    key::Type{<:EntryType},
) =
    ComponentTimedMetric(name, description,
        (res::IS.Results, comp::Component,
            start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) ->
            read_component_result(res, key, comp, start_time, len))

# TODO test
"Convenience function to convert a SystemEntryType to a function and make a SystemTimedMetric from it"
make_system_metric_from_entry(
    name::String,
    description::String,
    key::Type{<:SystemEntryType},
) =
    SystemTimedMetric(name, description,
        (res::IS.Results,
            start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) ->
            read_system_result(res, key, start_time, len))

# TODO perhaps these built-in metrics should be in some sort of container TODO check with a
# domain expert, I feel like power and other metrics in 'per time' units should have
# time_agg_fn=mean but that's not how they're treated in the existing code
calc_active_power = make_component_metric_from_entry(
    "ActivePower",
    "Calculate the active power of the specified Entity",
    PSI.ActivePowerVariable,
)

calc_production_cost = make_component_metric_from_entry(
    "ProductionCost",
    "Calculate the active power output of the specified Entity",
    PSI.ProductionCostExpression,
)

calc_active_power_in = make_component_metric_from_entry(
    "ActivePowerIn",
    "Calculate the active power input to the specified (storage) Entity",
    PSI.ActivePowerInVariable,
)

calc_active_power_out = make_component_metric_from_entry(
    "ActivePowerOut",
    "Calculate the active power output of the specified (storage) Entity",
    PSI.ActivePowerOutVariable,
)

calc_stored_energy = make_component_metric_from_entry(
    "StoredEnergy",
    "Calculate the energy stored in the specified (storage) Entity",
    PSI.EnergyVariable,
)

calc_load_from_storage = compose_metrics(
    "LoadFromStorage",
    "Calculate the ActivePowerIn minus the ActivePowerOut of the specified (storage) Entity",
    (-),
    calc_active_power_in, calc_active_power_out)

calc_active_power_forecast = make_component_metric_from_entry(
    "ActivePowerForecast",
    "Fetch the forecast active power of the specified Entity",
    PSI.ActivePowerTimeSeriesParameter,
)

calc_load_forecast = ComponentTimedMetric(
    "LoadForecast",
    "Fetch the forecast active load of the specified Entity",
    # Load is negative power
    # NOTE if we had our own time-indexed dataframe type we could overload multiplication with a scalar and simplify this
    (args...) -> let
        val = compute(calc_active_power_forecast, args...)
        data_vec(val) .*= -1
        return val
    end,
)

calc_system_load_forecast = SystemTimedMetric(
    "SystemLoadForecast",
    "Fetch the forecast active load of all the ElectricLoad Components in the system",
    (res::IS.Results, st::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) ->
        compute(calc_load_forecast, res, make_entity(PSY.ElectricLoad), st, len),
)

calc_system_load_from_storage = let
    SystemTimedMetric(
        "SystemLoadFromStorage",
        "Fetch the LoadFromStorage of all storage in the system",
        (res::IS.Results, st::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) ->
            compute(calc_load_from_storage, res, make_entity(PSY.Storage), st, len),
    )
end

# TODO: check with domain expert that this should really be ActivePowerForecast and not ActivePower
calc_net_load_forecast = compose_metrics(
    "NetLoadForecast",
    "SystemLoadForecast minus ActivePowerForecast of the given Entity",
    (-),
    calc_system_load_forecast, calc_active_power_forecast)

calc_curtailment = compose_metrics(
    "Curtailment",
    "Calculate the ActivePowerForecast minus the ActivePower of the given Entity",
    (-),
    calc_active_power_forecast, calc_active_power,
)

calc_curtailment_frac = with_time_agg_fn(
    compose_metrics(
        "CurtailmentFrac",
        "Calculate the Curtailment as a fraction of the ActivePowerForecast of the given Entity",
        (./),
        calc_curtailment, calc_active_power_forecast,
    ), Statistics.mean)

calc_integration = with_time_agg_fn(
    compose_metrics(
        "Integration",
        "Calculate the ActivePower of the given Entity over the sum of the SystemLoadForecast and the SystemLoadFromStorage",
        ((power, load, storage) -> power ./ (load + storage)),
        calc_active_power, calc_system_load_forecast, calc_system_load_from_storage,
    ), Statistics.mean)

calc_capacity_factor = with_time_agg_fn(
    ComponentTimedMetric(
        "CapacityFactor",
        "Calculate the capacity factor (actual production/rated production) of the specified Entity",
        (
            (res::IS.Results, comp::Component,
                start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing},
            ) -> let
                val = compute(calc_active_power, res, comp, start_time, len)
                data_vec(val) .*= get_rating(comp)
                return val
            end
        ),
    ), Statistics.mean)

calc_startup_cost = ComponentTimedMetric(
    "StartupCost",
    "Calculate the startup cost of the specified Entity",
    (
        (res::IS.Results, comp::Component,
            start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) -> let
            val = read_component_result(res, PSI.StartVariable, comp, start_time, len)
            start_cost = PSY.get_start_up(PSY.get_operation_cost(comp))
            data_vec(val) .*= start_cost
            return val
        end
    ),
)

calc_shutdown_cost = ComponentTimedMetric(
    "ShutdownCost",
    "Calculate the shutdown cost of the specified Entity",
    (
        (res::IS.Results, comp::Component,
            start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) -> let
            val = read_component_result(res, PSI.StartVariable, comp, start_time, len)
            stop_cost = PSY.get_shut_down(PSY.get_operation_cost(comp))
            data_vec(val) .*= stop_cost
            return val
        end
    ),
)

calc_total_cost = ComponentTimedMetric(
    "TotalCost",
    "Calculate the production+startup+shutdown cost of the specified Entity; startup and shutdown costs are assumed to be zero if undefined",
    (args...) -> let
        production = compute(calc_production_cost, args...)
        startup = try
            data_vec(compute(calc_startup_cost, args...))
        catch
            repeat(0.0, size(production, 1))
        end
        shutdown = try
            data_vec(compute(calc_shutdown_cost, args...))
        catch
            repeat(0.0, size(production, 1))
        end
        # NOTE if I ever make my own type for timed dataframes, should do custom setindex! to make this less painful
        production[!, first(data_cols(production))] += startup + shutdown
        return production
    end,
)

calc_discharge_cycles = ComponentTimedMetric(
    "DischargeCycles",
    "Calculate the number of discharge cycles a storage device has gone through in the time period",
    (
        (res::IS.Results, comp::Component,
            start_time::Union{Nothing, Dates.DateTime}, len::Union{Int, Nothing}) -> let
            val = read_component_result(res, PSI.ActivePowerOutVariable, comp, start_time, len)
            soc_limits = get_state_of_charge_limits(comp)
            # TODO verify this algorithm with a domain expert
            soc_range = soc_limits.max
            # soc_range = soc_limits.max - soc_limits.min
            data_vec(val) ./= soc_range
            return val
        end
    ),
)

calc_system_slack_up = make_system_metric_from_entry(
    "SystemSlackUp",
    "Calculate the system balance slack up",
    PSI.SystemBalanceSlackUp,
)

"""
Create a boolean Metric for whether the given time period has system balance slack up of
magnitude greater than the `threshold` argument
"""
make_calc_is_slack_up(threshold::Real) = SystemTimedMetric(
    "IsSlackUp($threshold)",
    "Calculate whether the given time period has system balance slack up of magnitude greater than $threshold",
    (args...) -> let
        val = compute(calc_system_slack_up, args...)
        val[!, first(data_cols(val))] =
            abs.(val[!, first(data_cols(val))]) .> threshold
        return val
    end,
)

# TODO is this the appropriate place to put a default threshold (and is it the appropriate default)?
calc_is_slack_up = make_calc_is_slack_up(1e-3)

# TODO caching here too
make_results_metric_from_sum_optimizer_stat(
    name::String,
    description::String,
    stats_key::String) = ResultsTimelessMetric(
    name,
    description,
    (res::IS.Results) -> sum(PSI.read_optimizer_stats(res)[!, stats_key]),
)

calc_sum_objective_value = make_results_metric_from_sum_optimizer_stat(
    "SumObjectiveValue",
    "Sum the objective values achieved in the optimization problems",
    "objective_value")

calc_sum_solve_time = make_results_metric_from_sum_optimizer_stat(
    "SumSolveTime",
    "Sum the solve times taken by the optimization problems",
    "solve_time")

calc_sum_bytes_alloc = make_results_metric_from_sum_optimizer_stat(
    "SumBytesAlloc",
    "Sum the bytes allocated to the optimization problems",
    "solve_bytes_alloc")

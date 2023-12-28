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

# TODO perhaps these built-in metrics should be in some sort of container
calc_active_power = make_component_metric_from_entry(
    "ActivePower",
    "Calculate the active power output of the specified Entity",
    PSI.ActivePowerVariable,
)

calc_production_cost = make_component_metric_from_entry(
    "ProductionCost",
    "Calculate the active power output of the specified Entity",
    PSI.ProductionCostExpression,
)

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
            start_cost = PSY.get_shut_down(PSY.get_operation_cost(comp))
            data_vec(val) .*= start_cost
            return val
        end
    ),
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

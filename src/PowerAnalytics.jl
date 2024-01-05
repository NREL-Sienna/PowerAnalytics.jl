module PowerAnalytics

export make_fuel_dictionary
export get_generation_data
export get_load_data
export get_service_data
export categorize_data
export no_datetime

export Entity, EntityElement, EntitySet
export NAME_DELIMETER, subtype_to_string, component_to_qualified_string
export make_entity, default_name, get_name, get_subentities
export Metric, TimedMetric, TimelessMetric, EntityTimedMetric, ComponentTimedMetric,
    SystemTimedMetric, ResultsTimelessMetric, CustomTimedMetric
export DATETIME_COL, META_COL_KEY, SYSTEM_COL, RESULTS_COL
export is_col_meta, set_col_meta, set_col_meta!, time_df, time_vec, data_cols, data_df,
    data_vec, data_mat, get_description, get_entity_agg_fn, get_time_agg_fn,
    with_entity_agg_fn, with_time_agg_fn, metric_entity_to_string
export compute, compute_all, hcat_timed, aggregate_time, compose_metrics
export read_serialized_system,
    get_populated_decision_problem_results, create_problem_results_dict
export calc_active_power, calc_production_cost, calc_startup_cost, calc_shutdown_cost,
    calc_discharge_cycles, calc_system_slack_up, calc_load_forecast, calc_active_power_in,
    calc_active_power_out, calc_stored_energy, calc_active_power_forecast, calc_curtailment,
    calc_sum_objective_value, calc_sum_solve_time, calc_sum_bytes_alloc, calc_total_cost,
    make_calc_is_slack_up, calc_is_slack_up, calc_system_load_forecast,
    calc_net_load_forecast

#I/O Imports
import Dates
import TimeSeries
import DataFrames
import DataFrames: DataFrame, metadata, metadata!, colmetadata, colmetadata!
import YAML
import DataStructures: OrderedDict, SortedDict
import PowerSystems
import PowerSystems: Component, get_component, get_components, get_available
import InfrastructureSystems
import InfrastructureSystems: get_name
import PowerSimulations
import InteractiveUtils

const PSY = PowerSystems
const IS = InfrastructureSystems
const PSI = PowerSimulations

include("definitions.jl")
include("get_data.jl")
include("fuel_results.jl")

include("entities.jl")
include("metrics.jl")
include("input.jl")
include("builtin_metrics.jl")

greet() = print("Hello World!")

end # module PowerAnalytics

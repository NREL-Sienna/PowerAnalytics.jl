# For now we are mostly just testing that all the metrics can be called without error,
# though I've built out the structure to do much more than that. TODO it would be great if
# we did.

(results_uc, results_ed) = run_test_sim(TEST_RESULT_DIR, TEST_SIM_NAME)
const ResultType = AbstractDataFrame

# Future implementers of built-in metrics must add tests as shown below or this will trigger
function test_metric(::Val{metric_name}) where {metric_name}
    throw("Could not find test for $metric_name")
end

function test_metric(::Val{:calc_active_power})
    @test calc_active_power(make_selector(ThermalStandard), results_uc) isa ResultType
end

function test_metric(::Val{:calc_active_power_forecast})
    @test calc_active_power_forecast(make_selector(RenewableDispatch), results_uc) isa
          ResultType
end

function test_metric(::Val{:calc_active_power_in})
    @test calc_active_power_in(make_selector(EnergyReservoirStorage), results_uc) isa
          ResultType
end

function test_metric(::Val{:calc_active_power_out})
    @test calc_active_power_out(make_selector(EnergyReservoirStorage), results_uc) isa
          ResultType
end

function test_metric(::Val{:calc_capacity_factor})
    @test calc_capacity_factor(make_selector(RenewableDispatch), results_uc) isa ResultType
end

function test_metric(::Val{:calc_curtailment})
    @test calc_curtailment(make_selector(RenewableDispatch), results_uc) isa ResultType
end

function test_metric(::Val{:calc_curtailment_frac})
    @test calc_curtailment_frac(make_selector(RenewableDispatch), results_uc) isa ResultType
end

function test_metric(::Val{:calc_discharge_cycles})
    @test calc_discharge_cycles(make_selector(EnergyReservoirStorage), results_uc) isa
          ResultType
end

function test_metric(::Val{:calc_integration})
    @test calc_integration(make_selector(RenewableDispatch), results_uc) isa ResultType
end

function test_metric(::Val{:calc_is_slack_up})
    @test calc_is_slack_up(results_ed) isa ResultType
end

function test_metric(::Val{:calc_load_forecast})
    @test calc_load_forecast(make_selector(ElectricLoad), results_uc) isa ResultType
end

function test_metric(::Val{:calc_load_from_storage})
    @test calc_load_from_storage(make_selector(EnergyReservoirStorage), results_uc) isa
          ResultType
end

function test_metric(::Val{:calc_net_load_forecast})
    @test calc_load_from_storage(make_selector(EnergyReservoirStorage), results_uc) isa
          ResultType
end

function test_metric(::Val{:calc_production_cost})
    @test calc_production_cost(make_selector(ThermalStandard), results_uc) isa ResultType
end

function test_metric(::Val{:calc_shutdown_cost})
    @test calc_shutdown_cost(make_selector(ThermalStandard), results_uc) isa ResultType
end

function test_metric(::Val{:calc_startup_cost})
    @test calc_startup_cost(make_selector(ThermalStandard), results_uc) isa ResultType
end

function test_metric(::Val{:calc_stored_energy})
    @test calc_stored_energy(make_selector(EnergyReservoirStorage), results_uc) isa
          ResultType
end

function test_metric(::Val{:calc_sum_bytes_alloc})
    @test calc_sum_bytes_alloc(results_uc) isa ResultType
end

function test_metric(::Val{:calc_sum_objective_value})
    @test calc_sum_objective_value(results_uc) isa ResultType
end

function test_metric(::Val{:calc_sum_solve_time})
    @test calc_sum_solve_time(results_uc) isa ResultType
end

function test_metric(::Val{:calc_system_load_forecast})
    @test calc_system_load_forecast(results_uc) isa ResultType
end

function test_metric(::Val{:calc_system_load_from_storage})
    @test calc_system_load_from_storage(results_uc) isa ResultType
end

function test_metric(::Val{:calc_system_slack_up})
    @test calc_system_slack_up(results_ed) isa ResultType
end

function test_metric(::Val{:calc_total_cost})
    @test calc_total_cost(make_selector(ThermalStandard), results_uc) isa ResultType
end

all_metric_names = filter(x -> getproperty(PowerAnalytics.Metrics, x) isa Metric,
    names(PowerAnalytics.Metrics))

@testset for metric_name in all_metric_names
    test_metric(Val(metric_name))
end

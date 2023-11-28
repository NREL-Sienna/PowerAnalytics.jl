# Will be superseded by https://github.com/NREL-Sienna/PowerSystems.jl/issues/1143
function linear_fuel_to_linear_cost(fc::FuelCurve{LinearCurve})
    fuel_cost = get_fuel_cost(fc)
    !(fuel_cost isa Float64) && throw(ArgumentError("fuel_cost must be a scalar"))
    old_vc = get_value_curve(fc)
    new_vc = LinearCurve(
        get_proportional_term(old_vc) * fuel_cost,
        get_constant_term(old_vc) * fuel_cost,
    )
    return CostCurve(new_vc, get_power_units(fc), get_vom_cost(fc))
end

function add_re!(sys)
    re1 = RenewableDispatch(
        "WindBusA",
        true,
        get_component(ACBus, sys, "bus5"),
        0.0,
        0.0,
        1.200,
        PrimeMovers.WT,
        (min = 0.0, max = 0.0),
        1.0,
        RenewableGenerationCost(CostCurve(LinearCurve(0.220))),
        10.0,
    )
    add_component!(sys, re1)
    copy_time_series!(re1, get_component(PowerLoad, sys, "bus2"))

    re2 = RenewableDispatch(
        "SolarBusC",
        true,
        get_component(ACBus, sys, "bus1"),
        0.0,
        0.0,
        1.200,
        PrimeMovers.PVe,
        (min = 0.0, max = 0.0),
        1.0,
        TwoPartCost(0.220, 0.0),
        2.0,
    )
    add_component!(sys, re2)
    copy_time_series!(re2, get_component(PowerLoad, sys, "bus3"))

    fx = RenewableNonDispatch(
        "RoofTopSolar",
        true,
        get_component(ACBus, sys, "bus5"),
        0.0,
        0.0,
        1.100,
        PrimeMovers.PVe,
        1.0,
        10.0,
    )
    add_component!(sys, fx)
    copy_time_series!(fx, get_component(PowerLoad, sys, "bus2"))

    for g in get_components(HydroEnergyReservoir, sys)
        tpc = get_operation_cost(g)
        cc = get_variable(tpc)
        (cc isa FuelCurve) && (cc = linear_fuel_to_linear_cost(cc))
        smc = StorageCost(;
            charge_variable_cost = cc,
            discharge_variable_cost = cc,
            fixed = PSY.get_fixed(tpc),
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 10.0,
            energy_surplus_cost = 10.0,
        )
        set_operation_cost!(g, smc)
    end

    batt = EnergyReservoirStorage(;
        name = "test_batt",
        available = true,
        bus = get_component(ACBus, sys, "bus4"),
        prime_mover_type = PrimeMovers.BA,
        storage_technology_type = StorageTech.OTHER_CHEM,
        storage_capacity = 1.0,
        storage_level_limits = (min = 0.0, max = 1.0),
        initial_storage_capacity_level = 0.0,
        rating = 1.0,
        active_power = 0.0,
        input_active_power_limits = (min = 0.0, max = 1.0),
        output_active_power_limits = (min = 0.0, max = 1.0),
        efficiency = (in = 1.0, out = 1.0),
        reactive_power = 0.0,
        reactive_power_limits = nothing,
        base_power = 10.0,
    )
    add_component!(sys, batt)
end

function run_test_sim(result_dir::String, sim_name::String)
    mkpath(result_dir)
    sim_path = joinpath(result_dir, sim_name)

    results = _try_load_simulation_results(sim_path)
    if isnothing(results)
        if isdir(sim_path)
            rm(sim_path; recursive = true)
        end
        results = _execute_simulation(result_dir, sim_name)
    end

    results_uc = get_decision_problem_results(results, "UC")
    results_ed = get_decision_problem_results(results, "ED")

    return results_uc, results_ed
end

function _execute_simulation(base_path, sim_name)
    @info "Building UC system from"
    c_sys5_hy_uc = PSB.build_system(PSB.PSISystems, "5_bus_hydro_uc_sys")
    @info "Building ED system from"
    c_sys5_hy_ed = PSB.build_system(PSB.PSISystems, "5_bus_hydro_ed_sys")

    @info "Adding extra RE"
    add_re!(c_sys5_hy_uc)
    add_re!(c_sys5_hy_ed)

    GLPK_optimizer =
        optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.GLP_MSG_OFF)

    template_hydro_st_uc =
        ProblemTemplate(NetworkModel(CopperPlatePowerModel; use_slacks = false))
    set_device_model!(template_hydro_st_uc, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template_hydro_st_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_hydro_st_uc, RenewableNonDispatch, FixedOutput)
    set_device_model!(template_hydro_st_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_hydro_st_uc, HydroDispatch, FixedOutput)
    set_device_model!(
        template_hydro_st_uc,
        EnergyReservoirStorage,
        StorageDispatchWithReserves,
    )
    set_device_model!(
        template_hydro_st_uc,
        HydroEnergyReservoir,
        HydroDispatchReservoirStorage,
    )
    set_service_model!(template_hydro_st_uc, VariableReserve{ReserveUp}, RangeReserve)

    template_hydro_st_ed = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel;
            use_slacks = true,
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_device_model!(template_hydro_st_ed, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template_hydro_st_ed, PowerLoad, StaticPowerLoad)
    set_device_model!(template_hydro_st_ed, RenewableNonDispatch, FixedOutput)
    set_device_model!(template_hydro_st_ed, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_hydro_st_ed, HydroDispatch, FixedOutput)
    set_device_model!(
        template_hydro_st_ed,
        EnergyReservoirStorage,
        StorageDispatchWithReserves,
    )
    set_device_model!(
        template_hydro_st_ed,
        HydroEnergyReservoir,
        HydroDispatchReservoirStorage,
    )
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_hydro_st_uc,
                c_sys5_hy_uc;
                optimizer = GLPK_optimizer,
                name = "UC",
                system_to_file = true,
            ),
            DecisionModel(
                template_hydro_st_ed,
                c_sys5_hy_ed;
                optimizer = GLPK_optimizer,
                name = "ED",
                system_to_file = true,
            ),
        ],
    )

    sequence = SimulationSequence(;
        models = models,
        feedforwards = feedforward = Dict(
            "ED" => [
                SemiContinuousFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
                # TODO: restore this when it's fixed in PSI
                # EnergyLimitFeedforward(
                #     component_type = HydroEnergyReservoir,
                #     source = ActivePowerVariable,
                #     affected_values = [ActivePowerVariable],
                #     number_of_periods = 12,
                # ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )
    sim = Simulation(;
        name = sim_name,
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = base_path,
    )
    build!(sim)
    execute!(sim)
    return SimulationResults(sim)
end

function _try_load_simulation_results(sim_path)
    !isdir(sim_path) && return nothing
    c_sys5_hy_uc_path = get_system_file_path(joinpath(sim_path, "problems", "UC"))
    isnothing(c_sys5_hy_uc_path) && return nothing
    c_sys5_hy_ed_path = get_system_file_path(joinpath(sim_path, "problems", "ED"))
    isnothing(c_sys5_hy_ed_path) && return nothing
    !isfile(c_sys5_hy_uc_path) || !isfile(c_sys5_hy_ed_path) && return nothing

    try
        results = SimulationResults(sim_path)
        results_uc = get_decision_problem_results(results, "UC")
        results_ed = get_decision_problem_results(results, "ED")
        @info "Reading UC system from" sim_path
        c_sys5_hy_uc = System(c_sys5_hy_uc_path; time_series_read_only = true)
        @info "Reading ED system from" sim_path
        c_sys5_hy_ed = System(c_sys5_hy_ed_path; time_series_read_only = true)
        set_system!(results_uc, c_sys5_hy_uc)
        set_system!(results_ed, c_sys5_hy_ed)
        return results
    catch e
        @info "Failed to load the results from $sim_path. The results may be incomplete. $e"
    end

    return nothing
end

function get_system_file_path(path)
    !isdir(path) && return nothing
    files = readdir(path)
    for filename in files
        m = match(r"system-[\w-]+.json", filename)
        !isnothing(m) && return joinpath(path, m.match)
    end

    return nothing
end

function run_test_prob()
    c_sys5_hy_uc = PSB.build_system(PSB.PSISystems, "5_bus_hydro_uc_sys")
    add_re!(c_sys5_hy_uc)
    GLPK_optimizer =
        optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.GLP_MSG_OFF)

    template_hydro_st_uc = template_unit_commitment()
    set_device_model!(template_hydro_st_uc, HydroDispatch, FixedOutput)
    set_device_model!(
        template_hydro_st_uc,
        HydroEnergyReservoir,
        HydroDispatchReservoirStorage,
    )

    prob = DecisionModel(
        template_hydro_st_uc,
        c_sys5_hy_uc;
        optimizer = GLPK_optimizer,
        horizon = Hour(12),
    )
    build!(prob; output_dir = mktempdir())
    solve!(prob)
    res = OptimizationProblemResults(prob)
    return res
end

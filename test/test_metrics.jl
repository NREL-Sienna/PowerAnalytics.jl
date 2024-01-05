# LOAD RESULTS
(results_uc, results_ed) = run_test_sim(TEST_RESULT_DIR, TEST_SIM_NAME)
results_prob = run_test_prob()
resultses = Dict("UC" => results_uc, "ED" => results_ed, "prob" => results_prob)
@assert all(
    in.("ActivePowerVariable__ThermalStandard", list_variable_names.(values(resultses))),
) "Expected all results to contain ActivePowerVariable__ThermalStandard"
comp_results = Dict()  # Will be populated later

# CONSTRUCT COMMON TEST RESOURCES
test_calc_active_power = ComponentTimedMetric(
    "ActivePower",
    "Calculate the active power output of the specified Entity",
    (res::IS.Results, comp::Component,
        start_time::Union{Nothing, Dates.DateTime},
        len::Union{Int, Nothing}) -> let
        key = PSI.VariableKey(ActivePowerVariable, typeof(comp))
        res = PSI.read_results_with_keys(res, [key]; start_time = start_time, len = len)
        first(values(res))[!, [DATETIME_COL, get_name(comp)]]
    end,
)

test_calc_production_cost = ComponentTimedMetric(
    "ProductionCost",
    "Calculate the production cost of the specified Entity",
    (res::IS.Results, comp::Component,
        start_time::Union{Nothing, Dates.DateTime},
        len::Union{Int, Nothing}) -> let
        key = PSI.ExpressionKey(ProductionCostExpression, typeof(comp))
        res = PSI.read_results_with_keys(res, [key]; start_time = start_time, len = len)
        first(values(res))[!, [DATETIME_COL, get_name(comp)]]
    end,
)

test_calc_system_slack_up = SystemTimedMetric(
    "SystemSlackUp",
    "Calculate the system balance slack up",
    (res::IS.Results,
        start_time::Union{Nothing, Dates.DateTime},
        len::Union{Int, Nothing}) -> let
        key = PSI.VariableKey(SystemBalanceSlackUp, System)
        res = PSI.read_results_with_keys(res, [key]; start_time = start_time, len = len)
        res = first(values(res))
        # If there's more than a datetime column and a data column, we are misunderstanding
        @assert size(res, 2) == 2
        return DataFrames.rename(
            res,
            findfirst(!=(DATETIME_COL), names(res)) => SYSTEM_COL,
        )
    end,
)

test_calc_sum_objective_value = ResultsTimelessMetric(
    "SumObjectiveValue",
    "Sum the objective values achieved in the optimization problems",
    (res::IS.Results) -> sum(PSI.read_optimizer_stats(res)[!, "objective_value"]),
)

test_calc_sum_solve_time = ResultsTimelessMetric(
    "SumSolveTime",
    "Sum the solve times taken by the optimization problems",
    (res::IS.Results) -> sum(PSI.read_optimizer_stats(res)[!, "solve_time"]),
)

my_dates = [DateTime(2023), DateTime(2024)]
my_data1 = [3.14, 2.71]
my_data2 = [1.61, 1.41]
my_meta = [1, 2]

my_df1 = DataFrame(DATETIME_COL => my_dates, "MyComponent" => my_data1)
colmetadata!(my_df1, DATETIME_COL, META_COL_KEY, true; style = :note)

my_df2 = DataFrame(
    DATETIME_COL => my_dates,
    "Component1" => my_data1,
    "Component2" => my_data2,
    "MyMeta" => my_meta,
)
colmetadata!(my_df2, DATETIME_COL, META_COL_KEY, true; style = :note)
colmetadata!(my_df2, "MyMeta", META_COL_KEY, true; style = :note)

missing_df = DataFrame(
    DATETIME_COL => Vector{Union{Missing, Dates.DateTime}}([missing]),
    "MissingComponent" => 0.0)
colmetadata!(missing_df, DATETIME_COL, META_COL_KEY, true; style = :note)

my_dates_long = collect(DateTime(2023, 1, 1):Hour(8):DateTime(2023, 3, 31, 16))
my_data_long_1 = collect(range(0, 100, length(my_dates_long)))
my_data_long_2 = collect(range(24, 0, length(my_dates_long))) .+ 0.5 / length(my_dates_long)
my_meta_long = (my_dates_long .|> day) .% 2
my_df3 = DataFrame(
    DATETIME_COL => my_dates_long,
    "Component1" => my_data_long_1,
    "Component2" => my_data_long_2,
    "MyMeta" => my_meta_long,
)

# HELPER FUNCTIONS
function test_timed_metric_helper(computed_alltime, met, data_colname)
    test_generic_metric_helper(computed_alltime, met, data_colname)
    @test names(computed_alltime) == [DATETIME_COL, data_colname]
    @test eltype(computed_alltime[!, DATETIME_COL]) <: DateTime

    # Row tests, all time
    # TODO check that the number of rows is correct?
end

function test_generic_metric_helper(computed, met, data_colname)
    @test metadata(computed, "title") == met.name
    @test metadata(computed, "metric") === met
    @test colmetadata(computed, data_colname, "metric") ==
          metadata(computed, "metric")
    @test eltype(computed[!, data_colname]) <: Number
end

function test_component_timed_metric(met, res, ent, agg_fn = nothing)
    kwargs = (ent isa Component || agg_fn isa Nothing) ? Dict() : Dict(:agg_fn => agg_fn)
    computed_alltime = compute(met, res, ent; kwargs...)
    test_timed_metric_helper(computed_alltime, met, get_name(ent))

    # Row tests, specified time
    test_start_time = computed_alltime[2, DATETIME_COL]
    test_len = 3
    computed_sometime = compute(met, res, ent;
        start_time = test_start_time, len = test_len, kwargs...)
    @test computed_sometime[1, DATETIME_COL] == test_start_time
    @test size(computed_sometime, 1) == test_len

    the_components = (ent isa Component) ? [ent] : get_components(ent, get_system(res))
    @test all(colmetadata(computed_alltime, get_name(ent), "components") .== the_components)
    (ent isa Entity) && @test colmetadata(computed_alltime, get_name(ent), "entity") == ent

    return computed_alltime, computed_sometime
end

function test_system_timed_metric(met, res)
    computed_alltime = compute(met, res)
    test_timed_metric_helper(computed_alltime, met, SYSTEM_COL)
    @test compute(met, res, nothing) == computed_alltime

    # Row tests, specified time
    test_start_time = computed_alltime[2, DATETIME_COL]
    test_len = 3
    computed_sometime = compute(met, res; start_time = test_start_time, len = test_len)
    @test computed_sometime[1, DATETIME_COL] == test_start_time
    @test size(computed_sometime, 1) == test_len

    return computed_alltime, computed_sometime
end

function test_results_timeless_metric(met, res)
    computed = compute(met, res)
    test_generic_metric_helper(computed, met, RESULTS_COL)
    @test compute(met, res, nothing) == computed
    return computed
end

function test_df_approx_equal(lhs, rhs)
    @test all(names(lhs) .== names(rhs))
    for (lhs_col, rhs_col) in zip(eachcol(lhs), eachcol(rhs))
        if eltype(lhs_col) <: AbstractFloat || eltype(lhs_col) <: AbstractFloat
            @test all(isapprox.(lhs_col, rhs_col))
        else
            @test all(lhs_col .== rhs_col)
        end
    end
end

# BEGIN TEST SETS
@testset "Test metrics helper functions" begin
    @test metric_entity_to_string(test_calc_active_power, make_entity(ThermalStandard)) ==
          "ActivePower__ThermalStandard"

    @test is_col_meta(my_df2, DATETIME_COL)
    @test !is_col_meta(my_df2, "Component1")
    @test is_col_meta(my_df2, "MyMeta")

    my_df1_copy = copy(my_df1)
    @test !is_col_meta(my_df1_copy, "MyComponent")
    set_col_meta!(my_df1_copy, "MyComponent")
    @test is_col_meta(my_df1_copy, "MyComponent")
    set_col_meta!(my_df1_copy, "MyComponent", false)
    @test !is_col_meta(my_df1_copy, "MyComponent")

    @test time_df(my_df1) == DataFrame(DATETIME_COL => copy(my_dates))
    @test time_vec(my_df1) == copy(my_dates)
    @test data_df(my_df1) == DataFrame(; MyComponent = copy(my_data1))
    @test data_vec(my_df1) == copy(my_data1)
    @test data_mat(my_df1) == copy(my_data1)[:, :]

    @test data_cols(my_df2) == ["Component1", "Component2"]
    @test time_df(my_df2) == DataFrame(DATETIME_COL => copy(my_dates))
    @test time_vec(my_df2) == copy(my_dates)
    @test data_df(my_df2) ==
          DataFrame("Component1" => copy(my_data1), "Component2" => copy(my_data2))
    @test_throws ArgumentError data_vec(my_df2)
    @test data_mat(my_df2) == hcat(copy(my_data1), copy(my_data2))

    @test hcat_timed(my_df1, DataFrames.rename(my_df1, "MyComponent" => "YourComponent")) ==
          DataFrame(
        DATETIME_COL => my_dates,
        "MyComponent" => my_data1,
        "YourComponent" => my_data1,
    )
end

@testset "Test aggregate_time" begin
    test_df_approx_equal(
        aggregate_time(my_df3),
        DataFrame(
            DATETIME_COL => first(my_dates_long),
            "Component1" => sum(my_data_long_1),
            "Component2" => sum(my_data_long_2),
            "MyMeta" => sum(my_meta_long),
        ),
    )
    @test is_col_meta(aggregate_time(my_df3), DATETIME_COL)

    month_agg = aggregate_time(my_df3; groupby_fn = dt -> (year(dt), month(dt)))
    @test size(month_agg, 1) == 3
    test_df_approx_equal(
        month_agg[1:1, :],
        DataFrame(
            DATETIME_COL => first(my_dates_long),
            "Component1" => sum(my_data_long_1[1:(31 * 3)]),
            "Component2" => sum(my_data_long_2[1:(31 * 3)]),
            "MyMeta" => sum(my_meta_long[1:(31 * 3)]),
        ),
    )

    day_agg = aggregate_time(my_df3; groupby_fn = Date)
    @test size(day_agg, 1) == 31 + 28 + 31
    test_df_approx_equal(
        day_agg[1:1, :],
        DataFrame(
            DATETIME_COL => first(my_dates_long),
            "Component1" => sum(my_data_long_1[1:3]),
            "Component2" => sum(my_data_long_2[1:3]),
            "MyMeta" => sum(my_meta_long[1:3]),
        ),
    )

    hour_agg = aggregate_time(my_df3; groupby_fn = hour)
    @test size(hour_agg, 1) == 3
    test_df_approx_equal(
        hour_agg[1:1, :],
        DataFrame(
            DATETIME_COL => first(my_dates_long),
            "Component1" => sum(my_data_long_1[1:3:end]),
            "Component2" => sum(my_data_long_2[1:3:end]),
            "MyMeta" => sum(my_meta_long[1:3:end]),
        ),
    )

    for reduce_fn in (sum, length, (x -> sum(x) / length(x)), (_ -> 0))
        test_df_approx_equal(
            aggregate_time(my_df3; reduce_fn = reduce_fn),
            DataFrame(
                DATETIME_COL => first(my_dates_long),
                "Component1" => reduce_fn(my_data_long_1),
                "Component2" => reduce_fn(my_data_long_2),
                "MyMeta" => reduce_fn(my_meta_long),
            ),
        )
    end

    day_agg_2 = aggregate_time(my_df3; groupby_fn = Date, groupby_col = "day")
    @test "day" in names(day_agg_2)
    @test is_col_meta(day_agg_2, "day")
    @test day_agg_2[!, "day"] == Date.(time_vec(day_agg_2))
end

@testset "Test ComponentTimedMetric on Components" begin
    for (label, res) in pairs(resultses)
        comps1 = collect(get_components(RenewableDispatch, get_system(res)))
        comps2 = collect(get_components(ThermalStandard, get_system(res)))
        for comp in vcat(comps1, comps2)
            # This is a lot of testing, but we need all these in the dictionary anyway for
            # later, so we might as well test with all of them
            comp_results[(label, get_name(comp))] =
                test_component_timed_metric(test_calc_active_power, res, comp)
        end
    end
end

wind_ent = make_entity(RenewableDispatch, "WindBusA")
solar_ent = make_entity(RenewableDispatch, "SolarBusC")
thermal_ent = make_entity(ThermalStandard, "Brighton")
test_entities = [wind_ent, solar_ent, thermal_ent]
@testset "Test ComponentTimedMetric on EntityElements" begin
    for (label, res) in pairs(resultses)
        for ent in test_entities
            computed_alltime, computed_sometime =
                test_component_timed_metric(test_calc_active_power, res, ent)

            # EntityElement results should be the same as Component results
            component_name = get_name(first(get_components(ent, get_system(res))))
            base_computed_alltime, base_computed_sometime =
                comp_results[(label, component_name)]
            @test time_df(computed_alltime) == time_df(base_computed_alltime)
            # Using data_vec because the column names are allowed to differ
            @test data_vec(computed_alltime) == data_vec(base_computed_alltime)
            @test time_df(computed_sometime) == time_df(base_computed_sometime)
            @test data_vec(computed_sometime) == data_vec(base_computed_sometime)
        end
    end
end

@testset "Test ComponentTimedMetric on EntitySets" begin
    test_entitysets = [
        make_entity(wind_ent, solar_ent),
        make_entity(test_entities...),
        make_entity(ThermalStandard),
    ]

    for agg_fn in (sum, x -> sum(x) / length(x))
        for (label, res) in pairs(resultses)
            for ent in test_entitysets
                computed_alltime, computed_sometime =
                    test_component_timed_metric(test_calc_active_power, res, ent, agg_fn)

                component_names = get_name.(get_components(ent, get_system(res)))
                (base_computed_alltimes, base_computed_sometimes) =
                    zip([comp_results[(label, cn)] for cn in component_names]...)
                @test time_df(computed_alltime) == time_df(first(base_computed_alltimes))
                @test data_vec(computed_alltime) ==
                      agg_fn([data_vec(sub) for sub in base_computed_alltimes])
                @test time_df(computed_sometime) ==
                      time_df(first(base_computed_sometimes))
                @test data_vec(computed_sometime) ==
                      agg_fn([data_vec(sub) for sub in base_computed_sometimes])
            end
        end
    end
end

@testset "Test SystemTimedMetric" begin
    # The relevant data only exists in the ED results
    test_system_timed_metric(test_calc_system_slack_up, results_ed)
end

@testset "Test ResultsTimelessMetric" begin
    for (label, res) in pairs(resultses)
        test_results_timeless_metric(test_calc_sum_objective_value, res)
    end
end

@testset "Test compute_all" begin
    my_metrics = [test_calc_active_power, test_calc_active_power,
        test_calc_production_cost, test_calc_production_cost]
    my_component = first(get_components(RenewableDispatch, get_system(results_uc)))
    my_entities = [make_entity(ThermalStandard), make_entity(RenewableDispatch),
        make_entity(ThermalStandard), my_component]
    all_result = compute_all(results_uc, my_metrics, my_entities)

    for (metric, entity) in zip(my_metrics, my_entities)
        one_result = compute(metric, results_uc, entity)
        @test time_df(all_result) == time_df(one_result)
        @test all_result[!, metric_entity_to_string(metric, entity)] == data_vec(one_result)
        @test metadata(all_result, "results") == metadata(one_result, "results")
        # Comparing the components iterators with == gives false failures
        # TODO why do we need collect here but not in test_component_timed_metric?
        @test all(
            collect(
                colmetadata(
                    all_result,
                    metric_entity_to_string(metric, entity),
                    "components",
                ),
            ) .== collect(colmetadata(one_result, 2, "components")),
        )
        @test colmetadata(all_result, metric_entity_to_string(metric, entity), "metric") ==
              colmetadata(one_result, 2, "metric")
        (entity isa Component) || @test colmetadata(
            all_result,
            metric_entity_to_string(metric, entity),
            "entity",
        ) == colmetadata(one_result, 2, "entity")
    end

    my_names = ["Thermal Power", "Renewable Power", "Thermal Cost", "Renewable Cost"]
    all_result_named = compute_all(results_uc, my_metrics, my_entities, my_names)
    @test names(all_result_named) == vcat(DATETIME_COL, my_names...)
    @test time_df(all_result_named) == time_df(all_result)
    @test data_mat(all_result_named) == data_mat(all_result)

    @test_throws ArgumentError compute_all(results_uc, my_metrics, my_entities[2:end])
    @test_throws ArgumentError compute_all(results_uc, my_metrics, my_entities,
        my_names[2:end])

    for (label, res) in pairs(resultses)
        @test compute_all(res, [test_calc_sum_objective_value, test_calc_sum_solve_time],
            nothing, ["Met1", "Met2"]) == DataFrame(
            "Met1" => first(data_mat(compute(test_calc_sum_objective_value, res))),
            "Met2" => first(data_mat(compute(test_calc_sum_solve_time, res))))
    end

    broadcasted_compute_all = compute_all(
        results_uc,
        [test_calc_active_power, test_calc_active_power],
        make_entity(ThermalStandard),
        ["discard", "ThermalStandard"],
    )
    @test broadcasted_compute_all[!, [DATETIME_COL, "ThermalStandard"]] ==
          compute(test_calc_active_power, results_uc, make_entity(ThermalStandard))
end

@testset "Test compose_metrics" begin
    myent = make_entity(ThermalStandard)
    mymet1 = compose_metrics(
        "ThriceActivePower",
        "Computes ActivePower*3",
        (+),
        test_calc_active_power,
        test_calc_active_power,
        test_calc_active_power,
    )
    results1 = compute_all(
        results_uc,
        [test_calc_active_power, mymet1],
        [myent, myent],
        ["once", "thrice"],
    )
    @test all(results1[!, "once"] * 3 .== results1[!, "thrice"])

    mymet2 = compose_metrics(
        "ThriceSystemSlackUp",
        "Computes SystemSlackUp*3",
        (+),
        test_calc_system_slack_up,
        test_calc_system_slack_up,
        test_calc_system_slack_up,
    )
    results2 = compute_all(
        results_ed,
        [test_calc_system_slack_up, mymet2],
        nothing,
        ["once", "thrice"],
    )
    @test all(results2[!, "once"] * 3 .== results2[!, "thrice"])

    mymet3 = compose_metrics(
        "ThriceSumObjectiveValue",
        "Computes SumObjectiveValue*3",
        (+),
        test_calc_sum_objective_value,
        test_calc_sum_objective_value,
        test_calc_sum_objective_value,
    )
    results3 = compute_all(
        results_uc,
        [test_calc_sum_objective_value, mymet3],
        nothing,
        ["once", "thrice"],
    )
    @test all(results3[!, "once"] * 3 .== results3[!, "thrice"])

    mymet4 = compose_metrics(
        "SlackSlackPower",
        "Computes SystemSlackUp^2*ActivePower (element-wise)",
        (.*),
        test_calc_system_slack_up,
        test_calc_active_power,
        test_calc_system_slack_up,
    )
    results4 = compute_all(
        results_ed,
        [test_calc_system_slack_up, test_calc_active_power, mymet4],
        [nothing, myent, myent],
        ["slack", "power", "final"],
    )
    @test all(results4[!, "slack"].^2 .* results4[!, "power"] .== results4[!, "final"])
end

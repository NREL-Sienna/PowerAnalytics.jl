(results_uc, results_ed) = run_test_sim(TEST_RESULT_DIR, TEST_SIM_NAME)
results_prob = run_test_prob()
resultses = Dict("UC" => results_uc, "ED" => results_ed, "prob" => results_prob)
@assert all(
    in.("ActivePowerVariable__ThermalStandard", list_variable_names.(values(resultses))),
) "Expected all results to contain ActivePowerVariable__ThermalStandard"
comp_results = Dict()  # Will be populated later

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

function test_component_timed_metric(met, res, ent, agg_fn = nothing)
    kwargs = (ent isa Component || agg_fn isa Nothing) ? Dict() : Dict(:agg_fn => agg_fn)
    # Metadata tests
    computed_alltime = compute(met, res, ent; kwargs...)
    @test metadata(computed_alltime, "title") == met.name
    @test metadata(computed_alltime, "metric") === met
    the_components = (ent isa Component) ? [ent] : get_components(ent, get_system(res))
    @test colmetadata(computed_alltime, get_name(ent), "metric") ==
          metadata(computed_alltime, "metric")
    @test all(colmetadata(computed_alltime, get_name(ent), "components") .== the_components)
    (ent isa Entity) && @test colmetadata(computed_alltime, get_name(ent), "entity") == ent

    # Column tests
    @test names(computed_alltime) == [DATETIME_COL, get_name(ent)]
    @test eltype(computed_alltime[!, DATETIME_COL]) <: DateTime
    @test eltype(computed_alltime[!, get_name(ent)]) <: Number

    # Row tests, all time
    # TODO check that the number of rows is correct?

    # Row tests, specified time
    test_start_time = computed_alltime[2, DATETIME_COL]
    test_len = 3
    computed_sometime = compute(test_calc_active_power, res, ent;
        start_time = test_start_time, len = test_len, kwargs...)
    @test computed_sometime[1, DATETIME_COL] == test_start_time
    @test size(computed_sometime, 1) == test_len

    return computed_alltime, computed_sometime
end

@testset "Metrics helper functions" begin
    @test metric_entity_to_string(test_calc_active_power, make_entity(ThermalStandard)) ==
          "ActivePower__ThermalStandard"

    my_dates = [DateTime(2023), DateTime(2024)]
    my_data1 = [3.14, 2.71]
    my_data2 = [1.61, 1.41]
    my_meta = [1, 2]

    my_df1 = DataFrame(DATETIME_COL => my_dates, "MyComponent" => my_data1)
    @test time_df(my_df1) == DataFrame(DATETIME_COL => copy(my_dates))
    @test time_vec(my_df1) == copy(my_dates)
    @test data_df(my_df1) == DataFrame(; MyComponent = copy(my_data1))
    @test data_vec(my_df1) == copy(my_data1)
    @test data_mat(my_df1) == copy(my_data1)[:, :]

    my_df2 = DataFrame(
        DATETIME_COL => my_dates,
        "Component1" => my_data1,
        "Component2" => my_data2,
        "MyMeta" => my_meta,
    )
    colmetadata!(my_df2, "MyMeta", META_COL_KEY, true)
    @test data_cols(my_df2) == ["Component1", "Component2"]
    @test time_df(my_df2) == DataFrame(DATETIME_COL => copy(my_dates))
    @test time_vec(my_df2) == copy(my_dates)
    @test data_df(my_df2) ==
          DataFrame("Component1" => copy(my_data1), "Component2" => copy(my_data2))
    @test_throws ArgumentError data_vec(my_df2)
    @test data_mat(my_df2) == hcat(copy(my_data1), copy(my_data2))
end

@testset "ComponentTimedMetric on Components" begin
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
@testset "ComponentTimedMetric on EntityElements" begin
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

@testset "ComponentTimedMetric on EntitySets" begin
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

@testset "Non-fundamental Functions" begin
    my_metrics = [test_calc_active_power, test_calc_active_power,
        test_calc_production_cost, test_calc_production_cost]
    my_entities = [make_entity(ThermalStandard), make_entity(RenewableDispatch),
        make_entity(ThermalStandard), make_entity(RenewableDispatch)]
    all_result = compute_all(my_metrics, results_uc, my_entities)

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
        @test colmetadata(all_result, metric_entity_to_string(metric, entity), "entity") ==
              colmetadata(one_result, 2, "entity")
        @test colmetadata(all_result, metric_entity_to_string(metric, entity), "metric") ==
              colmetadata(one_result, 2, "metric")
    end

    my_names = ["Thermal Power", "Renewable Power", "Thermal Cost", "Renewable Cost"]
    all_result_named = compute_all(my_metrics, results_uc, my_entities, my_names)
    @test names(all_result_named) == vcat(DATETIME_COL, my_names...)
    @test time_df(all_result_named) == time_df(all_result)
    @test data_mat(all_result_named) == data_mat(all_result)

    @test_throws ArgumentError compute_all(my_metrics, results_uc, my_entities[2:end])
    @test_throws ArgumentError compute_all(my_metrics, results_uc, my_entities,
        my_names[2:end])
end

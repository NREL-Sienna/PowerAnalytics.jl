(results_uc, results_ed) = run_test_sim(TEST_RESULT_DIR)
results_prob = run_test_prob()
resultses = Dict("UC" => results_uc, "ED" => results_ed, "prob" => results_prob)
@assert all(
    in.("ActivePowerVariable__ThermalStandard", list_variable_names.(values(resultses))),
) "Expected all results to contain ActivePowerVariable__ThermalStandard"

test_calc_active_power = ComponentTimedMetric(
    "ActivePower",
    "Calculate the active power output of the specified Entity",
    (res::IS.Results, comp::Component,
        start_time::Union{Nothing, Dates.DateTime},
        len::Union{Int, Nothing}) -> let
        key = PSI.VariableKey(ActivePowerVariable, typeof(comp))
        res = PSI.read_results_with_keys(res, [key]; start_time = start_time, len = len)
        first(values(res))[!, ["DateTime", get_name(comp)]]
    end,
)

function test_component_timed_metric(met, res, ent, agg_fn = nothing)
    kwargs = (ent isa Component || agg_fn isa Nothing) ? Dict() : Dict(:agg_fn => agg_fn)
    # Metadata tests
    computed_alltime = compute(met, res, ent; kwargs...)
    @test metadata(computed_alltime, "title") == met.name
    @test metadata(computed_alltime, "metric") === met
    the_components = (ent isa Component) ? [ent] : get_components(ent, get_system(res))
    @test all(colmetadata(computed_alltime, get_name(ent), "components") .== the_components)
    (ent isa Entity) && @test colmetadata(computed_alltime, get_name(ent), "entity") == ent

    # Column tests
    @test names(computed_alltime) == ["DateTime", get_name(ent)]
    @test eltype(computed_alltime[!, "DateTime"]) <: DateTime
    @test eltype(computed_alltime[!, get_name(ent)]) <: Number

    # Row tests, all time
    # TODO check that the number of rows is correct?

    # Row tests, specified time
    test_start_time = computed_alltime[2, :DateTime]
    test_len = 3
    computed_sometime = compute(test_calc_active_power, res, ent;
        start_time = test_start_time, len = test_len, kwargs...)
    @test computed_sometime[1, :DateTime] == test_start_time
    @test size(computed_sometime, 1) == test_len

    return computed_alltime, computed_sometime
end

comp_results = Dict()
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
            @test computed_alltime[!, :DateTime] == base_computed_alltime[!, :DateTime]
            @test computed_alltime[!, 2] == base_computed_alltime[!, 2]
            @test computed_sometime[!, :DateTime] == base_computed_sometime[!, :DateTime]
            @test computed_sometime[!, 2] == base_computed_sometime[!, 2]
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
                @test computed_alltime[!, :DateTime] ==
                      first(base_computed_alltimes)[!, :DateTime]
                @test computed_alltime[!, 2] ==
                      agg_fn([sub[!, 2] for sub in base_computed_alltimes])
                @test computed_sometime[!, :DateTime] ==
                      first(base_computed_sometimes)[!, :DateTime]
                @test computed_sometime[!, 2] ==
                      agg_fn([sub[!, 2] for sub in base_computed_sometimes])
            end
        end
    end
end

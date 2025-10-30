stock_decision_results_sets = run_test_sim(TEST_RESULT_DIR, TEST_SIM_NAME)
stock_results_prob = run_test_prob()

sim_results = SimulationResults(TEST_RESULT_DIR, TEST_SIM_NAME)
decision_problem_names = ("UC", "ED")
my_results_sets = get_decision_problem_results.(Ref(sim_results), decision_problem_names)

(results_uc, results_ed) = stock_decision_results_sets
resultses = Dict("UC" => results_uc, "ED" => results_ed, "prob" => stock_results_prob)

# Reimplements Base.Filesystem.cptree since that isn't exported
function cptree(src::String, dst::String)
    mkdir(dst)
    for name in readdir(src)
        srcname = joinpath(src, name)
        if isdir(srcname)
            cptree(srcname, joinpath(dst, name))
        else
            cp(srcname, joinpath(dst, name))
        end
    end
end

# Create another results directory
function setup_duplicate_results()
    teardown_duplicate_results()
    cptree(
        joinpath(TEST_RESULT_DIR, TEST_SIM_NAME),
        joinpath(TEST_RESULT_DIR, TEST_DUPLICATE_RESULTS_NAME),
    )
end

function teardown_duplicate_results()
    rm(joinpath(TEST_RESULT_DIR, TEST_DUPLICATE_RESULTS_NAME);
        force = true, recursive = true)
end

@testset "Test create_problem_results_dict" begin
    setup_duplicate_results()
    for (problem, stock_results) in zip(decision_problem_names, stock_decision_results_sets)
        scenario_names = [TEST_SIM_NAME, TEST_DUPLICATE_RESULTS_NAME]
        scenarios = create_problem_results_dict(TEST_RESULT_DIR, problem)
        @test Set(keys(scenarios)) == Set(scenario_names)
        scenarios = create_problem_results_dict(TEST_RESULT_DIR, problem, scenario_names)
        @test Set(keys(scenarios)) == Set(scenario_names)
        @test IS.compare_values(
            get_system!(scenarios[TEST_SIM_NAME]),
            get_system(stock_results),
        )
    end
    teardown_duplicate_results()
end

@testset "Test read_component_result" begin
    for res in values(resultses)
        entry = ActivePowerVariable
        comp = get_component(ThermalStandard, get_system(res), "Solitude")
        my_result = PA.read_component_result(res, entry, comp)
        key = PSI.VariableKey(entry, ThermalStandard)
        existing_result = only(
            values(
                PSI.read_results_with_keys(res, [key]; table_format = IS.TableFormat.WIDE),
            ),
        )[
            !,
            ["DateTime", "Solitude"],
        ]
        @test my_result == existing_result
    end
end

@testset "Test read_system_result" begin
    entry = SystemBalanceSlackUp
    my_result = PA.read_system_result(results_ed, entry)
    key = PSI.VariableKey(entry, System)
    existing_result = only(
        values(
            PSI.read_results_with_keys(
                results_ed,
                [key];
                table_format = IS.TableFormat.WIDE,
            ),
        ),
    )
    @test get_time_vec(my_result) == get_time_vec(existing_result)
    @test get_data_vec(my_result) == get_data_vec(existing_result)
end

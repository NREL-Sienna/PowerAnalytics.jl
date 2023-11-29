stock_decision_results_sets = run_test_sim(TEST_RESULT_DIR, TEST_SIM_NAME)
stock_results_prob = run_test_prob()

sim_results = SimulationResults(TEST_RESULT_DIR, TEST_SIM_NAME)
decision_problem_names = ("UC", "ED")
my_results_sets = get_decision_problem_results.(Ref(sim_results), decision_problem_names)
populated_results_sets =
    get_populated_decision_problem_results.(Ref(sim_results), decision_problem_names)

# TODO is there a better way?
function test_system_equivalence(sys1::System, sys2::System)
    @test ==(((sys1, sys2) .|> IS.get_internal .|> IS.get_uuid)...)
    @test sort(get_name.(get_components(Component, sys1))) ==
          sort(get_name.(get_components(Component, sys2)))
end

@testset "Test per-results functions" begin
    for (populated_results, my_results, stock_results) in
        zip(populated_results_sets, my_results_sets, stock_decision_results_sets)
        test_system_equivalence(
            read_serialized_system(my_results),
            get_system(stock_results),
        )
        test_system_equivalence(get_system(populated_results), get_system(stock_results))
        # NOTE: why does get_units_base return a string and not an enum value?
        @test get_units_base(get_system(populated_results)) ==
              string(IS.UnitSystem.NATURAL_UNITS)
    end
end

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

@testset "Test scenario-level functions" begin
    setup_duplicate_results()
    for (problem, stock_results) in zip(decision_problem_names, stock_decision_results_sets)
        scenarios = create_problem_results_dict(TEST_RESULT_DIR, problem)
        @test Set(keys(scenarios)) == Set([TEST_SIM_NAME, TEST_DUPLICATE_RESULTS_NAME])
        test_system_equivalence(
            get_system(scenarios[TEST_SIM_NAME]),
            get_system(stock_results),
        )
    end
    teardown_duplicate_results()
end

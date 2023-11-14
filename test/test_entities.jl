test_sys = PSB.build_system(PSB.PSITestSystems, "c_sys5_all_components")
test_gen = PSY.get_component(ThermalStandard, test_sys, "Solitude")

struct NonexistentComponent <: Component end

@testset "test helper functions" begin
    @test subtype_to_string(ThermalStandard) == "ThermalStandard"
    @test component_to_qualified_string(ThermalStandard, "Solitude") ==
          "ThermalStandard__Solitude"
    @test component_to_qualified_string(test_gen) == "ThermalStandard__Solitude"
end

@testset "test ComponentEntity" begin
    test_gen_ent = PA.ComponentEntity(ThermalStandard, "Solitude", nothing)
    named_test_gen_ent = PA.ComponentEntity(ThermalStandard, "Solitude", "SolGen")
    # Equality
    @test PA.ComponentEntity(ThermalStandard, "Solitude", nothing) == test_gen_ent
    @test PA.ComponentEntity(ThermalStandard, "Solitude", "SolGen") == named_test_gen_ent
    # Construction
    @test make_entity(ThermalStandard, "Solitude") == test_gen_ent
    @test make_entity(ThermalStandard, "Solitude", "SolGen") == named_test_gen_ent
    # Naming
    @test get_name(test_gen_ent) == "ThermalStandard__Solitude"
    @test get_name(named_test_gen_ent) == "SolGen"
    @test default_name(test_gen_ent) == "ThermalStandard__Solitude"
    # Contents
    @test get_components(make_entity(NonexistentComponent, ""), test_sys) ==
          Vector{Component}()
    the_components = get_components(test_gen_ent, test_sys)
    @test length(the_components) == 1
    @test typeof(first(the_components)) == ThermalStandard
    @test get_name(first(the_components)) == "Solitude"
end

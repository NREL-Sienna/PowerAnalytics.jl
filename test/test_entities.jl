test_sys = PSB.build_system(PSB.PSITestSystems, "c_sys5_all_components")
test_gen = PSY.get_component(ThermalStandard, test_sys, "Solitude")

struct NonexistentComponent <: Component end

@testset "Test helper functions" begin
    @test subtype_to_string(ThermalStandard) == "ThermalStandard"
    @test component_to_qualified_string(ThermalStandard, "Solitude") ==
          "ThermalStandard__Solitude"
    @test component_to_qualified_string(test_gen) == "ThermalStandard__Solitude"
end

@testset "Test ComponentEntity" begin
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
    @test collect(get_components(make_entity(NonexistentComponent, ""), test_sys)) ==
          Vector{Component}()
    the_components = collect(get_components(test_gen_ent, test_sys))
    @test length(the_components) == 1
    @test typeof(first(the_components)) == ThermalStandard
    @test get_name(first(the_components)) == "Solitude"
end

@testset "Test ListEntitySet" begin
    comp_ent_1 = make_entity(ThermalStandard, "Solitude")
    comp_ent_2 = make_entity(RenewableDispatch, "WindBusA")
    test_list_ent = PA.ListEntitySet((comp_ent_1, comp_ent_2), nothing)
    named_test_list_ent = PA.ListEntitySet((comp_ent_1, comp_ent_2), "TwoComps")

    # Equality
    @test PA.ListEntitySet((comp_ent_1, comp_ent_2), nothing) == test_list_ent

    # Construction
    @test make_entity(comp_ent_1, comp_ent_2) == test_list_ent
    @test make_entity(comp_ent_1, comp_ent_2; name = "TwoComps") == named_test_list_ent

    # Naming
    @test get_name(test_list_ent) ==
          "[ThermalStandard__Solitude, RenewableDispatch__WindBusA]"
    @test get_name(named_test_list_ent) == "TwoComps"

    # Contents
    @test collect(get_components(make_entity(), test_sys)) == Vector{Component}()
    the_components = collect(get_components(test_list_ent, test_sys))
    @test length(the_components) == 2
    @test get_component(ThermalStandard, test_sys, "Solitude") in the_components
    @test get_component(RenewableDispatch, test_sys, "WindBusA") in the_components
    the_subentities = collect(get_subentities(test_list_ent, test_sys))
    @test length(the_subentities) == 2
    @test comp_ent_1 in the_subentities
    @test comp_ent_2 in the_subentities
end

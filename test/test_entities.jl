test_sys = PSB.build_system(PSB.PSITestSystems, "c_sys5_all_components")
test_sys2 = PSB.build_system(PSB.PSISystems, "5_bus_hydro_uc_sys")

struct NonexistentComponent <: StaticInjection end  # <: Component

sort_name(x) = sort(x; by = get_name)

@testset "Test helper functions" begin
    @test subtype_to_string(ThermalStandard) == "ThermalStandard"
    @test component_to_qualified_string(ThermalStandard, "Solitude") ==
          "ThermalStandard__Solitude"
    @test component_to_qualified_string(
        PSY.get_component(ThermalStandard, test_sys, "Solitude"),
    ) == "ThermalStandard__Solitude"
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
    @test make_entity(get_component(ThermalStandard, test_sys, "Solitude")) == test_gen_ent

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
    @test PA.ListEntitySet((comp_ent_1, comp_ent_2), "TwoComps") == named_test_list_ent

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

    @test collect(get_subentities(make_entity(), test_sys)) == Vector{Entity}()
    the_subentities = collect(get_subentities(test_list_ent, test_sys))
    @test length(the_subentities) == 2
    @test comp_ent_1 in the_subentities
    @test comp_ent_2 in the_subentities
end

@testset "Test SubtypeEntitySet" begin
    test_sub_ent = PA.SubtypeEntitySet(ThermalStandard, nothing)
    named_test_sub_ent = PA.SubtypeEntitySet(ThermalStandard, "Thermals")

    # Equality
    @test PA.SubtypeEntitySet(ThermalStandard, nothing) == test_sub_ent
    @test PA.SubtypeEntitySet(ThermalStandard, "Thermals") == named_test_sub_ent

    # Construction
    @test make_entity(ThermalStandard) == test_sub_ent
    @test make_entity(ThermalStandard; name = "Thermals") == named_test_sub_ent

    # Naming
    @test get_name(test_sub_ent) == "ThermalStandard"
    @test get_name(named_test_sub_ent) == "Thermals"
    @test default_name(test_sub_ent) == "ThermalStandard"

    # Contents
    answer = sort_name(get_components(ThermalStandard, test_sys))

    @test collect(get_components(make_entity(NonexistentComponent), test_sys)) ==
          Vector{Component}()
    the_components = sort_name(get_components(test_sub_ent, test_sys))
    @test all(the_components .== answer)

    @test collect(get_subentities(make_entity(NonexistentComponent), test_sys)) ==
          Vector{EntityElement}()
    the_subentities = sort_name(get_subentities(test_sub_ent, test_sys))
    @test all(the_subentities .== make_entity.(answer))
end

@testset "Test TopologyEntitySet" begin
    topo1 = get_component(Area, test_sys2, "1")
    topo2 = get_component(LoadZone, test_sys2, "2")
    test_topo_ent1 = PA.TopologyEntitySet(Area, "1", ThermalStandard, nothing)
    test_topo_ent2 = PA.TopologyEntitySet(LoadZone, "2", StaticInjection, "Zone_2")
    @assert (test_topo_ent1 !== nothing) && (test_topo_ent2 !== nothing) "Relies on an out-of-date `5_bus_hydro_uc_sys` definition"

    # Equality
    @test PA.TopologyEntitySet(Area, "1", ThermalStandard, nothing) == test_topo_ent1
    @test PA.TopologyEntitySet(LoadZone, "2", StaticInjection, "Zone_2") == test_topo_ent2

    # Construction
    @test make_entity(Area, "1", ThermalStandard) == test_topo_ent1
    @test make_entity(LoadZone, "2", StaticInjection, "Zone_2") == test_topo_ent2

    # Naming
    @test get_name(test_topo_ent1) == "Area__1__ThermalStandard"
    @test get_name(test_topo_ent2) == "Zone_2"

    # Contents
    empty_topo_ent = make_entity(Area, "1", NonexistentComponent)
    @test collect(get_components(empty_topo_ent, test_sys2)) == Vector{Component}()
    @test collect(get_subentities(empty_topo_ent, test_sys2)) == Vector{EntityElement}()

    answers =
        sort_name.((
            PSY.get_components_in_aggregation_topology(
                ThermalStandard,
                test_sys2,
                get_component(Area, test_sys2, "1"),
            ),
            PSY.get_components_in_aggregation_topology(
                StaticInjection,
                test_sys2,
                get_component(LoadZone, test_sys2, "2"),
            )))
    for (ent, ans) in zip((test_topo_ent1, test_topo_ent2), answers)
        @assert length(ans) > 0 "Relies on an out-of-date `5_bus_hydro_uc_sys` definition"

        the_components = sort_name(get_components(ent, test_sys2))
        @test all(the_components .== ans)

        the_subentities = sort_name(get_subentities(ent, test_sys2))
        @test all(the_subentities .== sort_name(make_entity.(ans)))
    end
end

@testset "Test FilterEntitySet" begin
    starts_with_s(x) = lowercase(first(get_name(x))) == 's'
    test_filter_ent = PA.FilterEntitySet(starts_with_s, ThermalStandard, nothing)
    named_test_filter_ent =
        PA.FilterEntitySet(starts_with_s, ThermalStandard, "ThermStartsWithS")

    # Equality
    @test PA.FilterEntitySet(starts_with_s, ThermalStandard, nothing) == test_filter_ent
    @test PA.FilterEntitySet(starts_with_s, ThermalStandard, "ThermStartsWithS") ==
          named_test_filter_ent

    # Construction
    @test make_entity(starts_with_s, ThermalStandard) == test_filter_ent
    @test make_entity(starts_with_s, ThermalStandard, "ThermStartsWithS") ==
          named_test_filter_ent
    bad_input_fn(x::Integer) = true  # Should always fail to construct
    specific_input_fn(x::RenewableDispatch) = true  # Should require compatible subtype
    @test_throws ArgumentError make_entity(bad_input_fn, ThermalStandard)
    @test_throws ArgumentError make_entity(specific_input_fn, Component)
    @test_throws ArgumentError make_entity(specific_input_fn, ThermalStandard)
    @test make_entity(specific_input_fn, RenewableDispatch) isa Any  # test absence of error

    # Naming
    @test get_name(test_filter_ent) == "starts_with_s__ThermalStandard"
    @test get_name(named_test_filter_ent) == "ThermStartsWithS"

    # Contents
    answer = filter(starts_with_s, collect(get_components(ThermalStandard, test_sys)))

    @test collect(get_components(make_entity(x -> true, NonexistentComponent), test_sys)) ==
          Vector{Component}()
    @test collect(get_components(make_entity(x -> false, Component), test_sys)) ==
          Vector{Component}()
    @test all(collect(get_components(test_filter_ent, test_sys)) .== answer)

    @test collect(
        get_subentities(make_entity(x -> true, NonexistentComponent), test_sys),
    ) == Vector{EntityElement}()
    @test collect(get_subentities(make_entity(x -> false, Component), test_sys)) ==
          Vector{EntityElement}()
    @test all(collect(get_subentities(test_filter_ent, test_sys)) .== make_entity.(answer))
end

test_sys = PSB.build_system(PSB.PSITestSystems, "c_sys5_all_components")
test_sys2 = PSB.build_system(PSB.PSITestSystems, "c_sys5_bat")
name_and_type = component -> (typeof(component), get_name(component))

@testset "Test `all_loads` and `all_storage`" begin
    @test Set(name_and_type.(get_components(all_loads, test_sys))) ==
          Set([(PowerLoad, "Bus2"), (PowerLoad, "Bus4"), (StandardLoad, "Bus3")])
    @test Set(name_and_type.(get_components(all_storage, test_sys2))) ==
          Set([(EnergyReservoirStorage, "Bat")])
end

@testset "Test `generator_mapping.yaml`-based functionality" begin
    @test isfile(PA.FUEL_TYPES_DATA_FILE)
    @test Set(keys(injector_categories)) ==
          Set(["Biopower", "CSP", "Coal", "Geothermal", "Hydropower", "NG-CC", "NG-CT",
        "NG-Steam", "Nuclear", "Other", "PV", "Petroleum", "Wind",
        "Storage", "Load"])
    @test Set(keys(generator_categories)) ==
          Set(["Biopower", "CSP", "Coal", "Geothermal", "Hydropower", "NG-CC", "NG-CT",
        "NG-Steam", "Nuclear", "Other", "PV", "Petroleum", "Wind"])
    @test Set(
        name_and_type.(get_components(injector_categories["Wind"], test_sys)),
    ) == Set([(RenewableDispatch, "WindBusB"), (RenewableDispatch, "WindBusC"),
        (RenewableDispatch, "WindBusA")])
    @test Set(
        name_and_type.(get_components(generator_categories["Coal"], test_sys)),
    ) == Set([(ThermalStandard, "Park City"), (ThermalStandard, "Sundance"),
        (ThermalStandard, "Alta"), (ThermalStandard, "Solitude"),
        (ThermalStandard, "Brighton")])
    @test Set(get_groups(categorized_injectors, test_sys)) ==
          Set(values(injector_categories))
    @test Set(get_groups(categorized_generators, test_sys)) ==
          Set(values(generator_categories))
    @test Set(keys(first(parse_generator_mapping_file(PA.FUEL_TYPES_DATA_FILE)))) ==
          Set(keys(injector_categories))
end

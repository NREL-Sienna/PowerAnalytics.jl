test_sys = PSB.build_system(PSB.PSITestSystems, "c_sys5_all_components")
test_sys2 = PSB.build_system(PSB.PSITestSystems, "c_sys5_bat")
name_and_type = component -> (typeof(component), get_name(component))

@testset "Test load_component_selector and storage_component_selector" begin
    @test Set(name_and_type.(get_components(load_component_selector, test_sys))) ==
          Set([(PowerLoad, "Bus2"), (PowerLoad, "Bus4"), (StandardLoad, "Bus3")])
    @test Set(name_and_type.(get_components(storage_component_selector, test_sys2))) ==
          Set([(EnergyReservoirStorage, "Bat")])
end

@testset "Test generator_selectors_by_fuel" begin
    @test isfile(PA.FUEL_TYPES_DATA_FILE)
    @test Set(keys(generator_selectors_by_fuel)) ==
          Set(["Biopower", "CSP", "Coal", "Geothermal", "Hydropower", "NG-CC", "NG-CT",
        "NG-Steam", "Natural gas", "Nuclear", "Other", "PV", "Petroleum", "Storage",
        "Wind"])
    @test Set(
        name_and_type.(get_components(generator_selectors_by_fuel["Wind"], test_sys)),
    ) == Set([(RenewableDispatch, "WindBusB"), (RenewableDispatch, "WindBusC"),
        (RenewableDispatch, "WindBusA")])
    @test Set(
        name_and_type.(get_components(generator_selectors_by_fuel["Coal"], test_sys)),
    ) == Set([(ThermalStandard, "Park City"), (ThermalStandard, "Sundance"),
        (ThermalStandard, "Alta"), (ThermalStandard, "Solitude"),
        (ThermalStandard, "Brighton")])
end

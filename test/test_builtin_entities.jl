test_sys = PSB.build_system(PSB.PSITestSystems, "c_sys5_all_components")
test_sys2 = PSB.build_system(PSB.PSITestSystems, "c_sys5_bat")
name_and_type = component -> (typeof(component), get_name(component))

@testset "Test load_entity and storage_entity" begin
    @test Set(name_and_type.(get_components(load_entity, test_sys))) ==
          Set([(PowerLoad, "Bus2"), (PowerLoad, "Bus4"), (StandardLoad, "Bus3")])
    @test Set(name_and_type.(get_components(storage_entity, test_sys2))) ==
          Set([(GenericBattery, "Bat")])
end

@testset "Test generator_entities_by_fuel" begin
    @test isfile(PA.FUEL_TYPES_DATA_FILE)
    @test Set(keys(generator_entities_by_fuel)) ==
          Set(["Biopower", "CSP", "Coal", "Geothermal", "Hydropower", "NG-CC", "NG-CT",
        "NG-Steam", "Natural gas", "Nuclear", "Other", "PV", "Petroleum", "Storage",
        "Wind"])
    @test Set(
        name_and_type.(get_components(generator_entities_by_fuel["Wind"], test_sys)),
    ) == Set([(RenewableDispatch, "WindBusB"), (RenewableDispatch, "WindBusC"),
        (RenewableDispatch, "WindBusA")])
    @test Set(
        name_and_type.(get_components(generator_entities_by_fuel["Coal"], test_sys)),
    ) == Set([(ThermalStandard, "Park City"), (ThermalStandard, "Sundance"),
        (ThermalStandard, "Alta"), (ThermalStandard, "Solitude"),
        (ThermalStandard, "Brighton")])
end

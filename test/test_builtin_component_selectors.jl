test_sys = PSB.build_system(PSB.PSITestSystems, "c_sys5_all_components")
test_sys2 = PSB.build_system(PSB.PSITestSystems, "c_sys5_bat")
name_and_type = component -> (typeof(component), get_name(component))

@testset "Test `all_loads` and `all_storage`" begin
    @test Set(name_and_type.(get_components(all_loads, test_sys))) ==
          Set([(PowerLoad, "Bus2"), (PowerLoad, "Bus4"), (StandardLoad, "Bus3")])
    @test Set(name_and_type.(get_components(all_storage, test_sys2))) ==
          Set([(EnergyReservoirStorage, "Bat")])
end

# TODO rewrite based on refactored selectors
# @testset "Test `generators_of_category` and `generators_by_category`" begin
#     @test isfile(PA.FUEL_TYPES_DATA_FILE)
#     @test Set(keys(generators_of_category)) ==
#           Set(["Biopower", "CSP", "Coal", "Geothermal", "Hydropower", "NG-CC", "NG-CT",
#         "NG-Steam", "Natural gas", "Nuclear", "Other", "PV", "Petroleum", "Storage",
#         "Wind"])
#     @test Set(
#         name_and_type.(get_components(generators_of_category["Wind"], test_sys)),
#     ) == Set([(RenewableDispatch, "WindBusB"), (RenewableDispatch, "WindBusC"),
#         (RenewableDispatch, "WindBusA")])
#     @test Set(
#         name_and_type.(get_components(generators_of_category["Coal"], test_sys)),
#     ) == Set([(ThermalStandard, "Park City"), (ThermalStandard, "Sundance"),
#         (ThermalStandard, "Alta"), (ThermalStandard, "Solitude"),
#         (ThermalStandard, "Brighton")])
#     @test Set(get_groups(generators_by_category, test_sys)) ==
#           Set(values(generators_of_category))
#     @test Set(keys(parse_generator_mapping(PA.FUEL_TYPES_DATA_FILE))) ==
#           Set(keys(generators_of_category))
# end

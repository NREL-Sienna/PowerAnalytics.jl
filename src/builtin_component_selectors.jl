const FUEL_TYPES_DATA_FILE =
    joinpath(dirname(dirname(pathof(PowerAnalytics))), "deps", "generator_mapping.yaml")

# Parse the strings in generator_mapping.yaml into types and enum items
function parse_fuel_category(category_spec::Dict)
    # TODO support types beyond PowerSystems
    gen_type = getproperty(PowerSystems, Symbol(get(category_spec, "gentype", Component)))
    (gen_type === Any) && (gen_type = Component)
    @assert gen_type <: Component

    pm = get(category_spec, "primemover", nothing)
    isnothing(pm) || (pm = PSY.parse_enum_mapping(PSY.PrimeMovers, pm))

    fc = get(category_spec, "fuel", nothing)
    isnothing(fc) || (fc = PSY.parse_enum_mapping(PSY.ThermalFuels, fc))

    return gen_type, pm, fc
end

function make_fuel_component_selector(category_spec::Dict)
    parse_results = parse_fuel_category(category_spec)
    (gen_type, prime_mover, fuel_category) = parse_results

    function filter_closure(comp::Component)
        comp_sig = Tuple{typeof(comp)}
        if !isnothing(prime_mover)
            hasmethod(PowerSystems.get_prime_mover_type, comp_sig) || return false
            (PowerSystems.get_prime_mover_type(comp) == prime_mover) || return false
        end
        if !isnothing(fuel_category)
            hasmethod(PowerSystems.get_fuel, comp_sig) || return false
            (PowerSystems.get_fuel(comp) == fuel_category) || return false
        end
        return true
    end

    # Create a nice name that is guaranteed to never collide with fully-qualified component names
    selector_name = join(ifelse.(isnothing.(parse_results), "", string.(parse_results)),
        COMPONENT_NAME_DELIMITER)

    return make_selector(gen_type, filter_closure; name = selector_name)
end

# Based on old PowerAnalytics' get_generator_mapping
function parse_generator_mapping(filename)
    # NOTE the YAML library does not support ordered loading
    in_data = open(YAML.load, filename)
    mappings = Dict{String, ComponentSelector}()
    for top_level in keys(in_data)
        subselectors = make_fuel_component_selector.(in_data[top_level])
        mappings[top_level] = make_selector(subselectors...; name = top_level)
    end
    return mappings
end

# SELECTORS MODULE
"`PowerAnalytics` built-in `ComponentSelector`s. Use `names` to list what is available."
module Selectors
import
    ..make_selector,
    ..PSY,
    ..parse_generator_mapping,
    ..ComponentSelector,
    ..FUEL_TYPES_DATA_FILE
export
    all_loads,
    all_storage,
    generators_of_category,
    generators_by_category

"A ComponentSelector representing all the electric load in a System"
all_loads::ComponentSelector = make_selector(PSY.ElectricLoad)

"A ComponentSelector representing all the storage in a System"
all_storage::ComponentSelector = make_selector(PSY.Storage)

"""
A dictionary of `ComponentSelector`s, each of which corresponds to one of the generator
reporting categories in `generator_mapping.yaml`. Use `generators_by_reporting_category`
if instead a single selector grouped by all the categories is desired.
"""
generators_of_category::AbstractDict{String, ComponentSelector} =
    parse_generator_mapping(FUEL_TYPES_DATA_FILE)

"""
A single `ComponentSelector` representing the generators in a `System` grouped by the
reporting categories in `generator_mapping.yaml`. Use `generators_of_reporting_category`
if instead an individual category is desired.
"""
generators_by_category::ComponentSelector =
    make_selector(values(generators_of_category)...)
end

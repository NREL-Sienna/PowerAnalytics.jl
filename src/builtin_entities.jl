"An Entity representing all the electric load in a System"
load_entity = make_entity(PSY.ElectricLoad)

"An Entity representing all the storage in a System"
storage_entity = make_entity(PSY.Storage)

FUEL_TYPES_DATA_FILE =
    joinpath(dirname(dirname(pathof(PowerAnalytics))), "deps", "generator_mapping.yaml")

# Parse the strings in generator_mapping.yaml into types and enum items
function parse_fuel_category(category_spec::Dict)
    # Use reflection to look up the type corresponding the generator type string (this isn't a security risk, is it?)
    gen_type = getproperty(PowerSystems, Symbol(get(category_spec, "gentype", Component)))
    (gen_type === Any) && (gen_type = Component)
    @assert gen_type <: Component

    pm = get(category_spec, "primemover", nothing)
    isnothing(pm) || (pm = PowerSystems.parse_enum_mapping(PowerSystems.PrimeMovers, pm))

    fc = get(category_spec, "fuel", nothing)
    isnothing(fc) || (fc = PowerSystems.parse_enum_mapping(PowerSystems.ThermalFuels, fc))

    return gen_type, pm, fc
end

function make_fuel_entity(category_spec::Dict)
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
    entity_name = join(ifelse.(isnothing.(parse_results), "", string.(parse_results)),
        NAME_DELIMETER)

    return make_entity(filter_closure, gen_type, entity_name)
end

# Based on old PowerAnalytics' get_generator_mapping
function load_generator_fuel_mappings(filename = FUEL_TYPES_DATA_FILE)
    in_data = open(YAML.load, filename)
    mappings = OrderedDict{String, Entity}()
    for top_level in in_data |> keys |> collect |> sort
        sub_entities = make_fuel_entity.(in_data[top_level])
        mappings[top_level] = make_entity(sub_entities...; name = top_level)
    end
    return mappings
end

"A dictionary of nested entities representing all the generators in a System categorized by fuel type"
generator_entities_by_fuel = load_generator_fuel_mappings()

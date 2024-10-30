const FUEL_TYPES_DATA_FILE =
    joinpath(dirname(dirname(pathof(PowerAnalytics))), "deps", "generator_mapping.yaml")
const FUEL_TYPES_META_KEY = "__META"

# Parse the strings in generator_mapping.yaml into types and enum items
function parse_fuel_category(
    category_spec::Dict;
    root_type::Type{<:Component} = PSY.StaticInjection,
)
    # TODO support types beyond PowerSystems
    gen_type = getproperty(PowerSystems, Symbol(get(category_spec, "gentype", Component)))
    (gen_type === Any) && (gen_type = root_type)
    # Constrain gen_type such that gen_type <: root_type
    gen_type = typeintersect(gen_type, root_type)

    pm = get(category_spec, "primemover", nothing)
    isnothing(pm) || (pm = PSY.parse_enum_mapping(PSY.PrimeMovers, pm))

    fc = get(category_spec, "fuel", nothing)
    isnothing(fc) || (fc = PSY.parse_enum_mapping(PSY.ThermalFuels, fc))

    return gen_type, pm, fc
end

function make_fuel_component_selector(
    category_spec::Dict;
    root_type::Type{<:Component} = PSY.StaticInjection,
)
    parse_results = parse_fuel_category(category_spec; root_type = root_type)
    (gen_type, prime_mover, fuel_category) = parse_results
    # If gen_type is the bottom type, it means it doesn't fit in root_type and we shouldn't include the selector at all
    (gen_type <: Union{}) && return nothing

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

    return make_selector(filter_closure, gen_type; name = selector_name)
end

# Based on old PowerAnalytics' get_generator_mapping
function parse_generator_mapping(
    filename;
    root_type::Type{<:Component} = PSY.StaticInjection,
)
    # NOTE the YAML library does not support ordered loading
    in_data = open(YAML.load, filename)
    mappings = Dict{String, ComponentSelector}()
    for top_level in keys(in_data)
        (top_level == FUEL_TYPES_META_KEY) && continue
        subselectors =
            make_fuel_component_selector.(
                in_data[top_level]; root_type = PSY.StaticInjection)
        # A subselector will be nothing if it doesn't fit under root_type
        subselectors = filter(!isnothing, subselectors)
        # Omit the category entirely if root_type causes elimination of all subselectors
        length(in_data[top_level]) > 0 && length(subselectors) == 0 && continue
        mappings[top_level] = make_selector(subselectors...; name = top_level)
    end
    return mappings, get(in_data, FUEL_TYPES_META_KEY, nothing)
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
    injector_categories,
    generator_categories,
    categorized_injectors,
    categorized_generators

"A ComponentSelector representing all the electric load in a System"
all_loads::ComponentSelector = make_selector(PSY.ElectricLoad)

"A ComponentSelector representing all the storage in a System"
all_storage::ComponentSelector = make_selector(PSY.Storage)

"""
A dictionary of `ComponentSelector`s, each of which corresponds to one of the static
injector categories in `generator_mapping.yaml`
"""
injector_categories::AbstractDict{String, ComponentSelector} =
    first(parse_generator_mapping(FUEL_TYPES_DATA_FILE))

"""
A dictionary of `ComponentSelector`s, each of which corresponds to one of the categories in
`generator_mapping.yaml`, only considering the components and categories that represent
`Generator`s (no storage or load)
"""
generator_categories::Union{AbstractDict{String, ComponentSelector}, Nothing} = let
    categories, meta =
        parse_generator_mapping(FUEL_TYPES_DATA_FILE)
    if isnothing(meta) || !haskey(meta, "non_generators")
        nothing
    else
        filter(pair -> !(first(pair) in meta["non_generators"]), categories)
    end
end

"""
A single `ComponentSelector` representing the static injectors in a `System` grouped by the
categories in `generator_mapping.yaml`
"""
categorized_injectors::ComponentSelector =
    make_selector(values(injector_categories)...)

"""
A single `ComponentSelector` representing the `Generator`s in a `System` grouped by the
categories in `generator_mapping.yaml`
"""
categorized_generators::Union{ComponentSelector, Nothing} =
    if isnothing(generator_categories)
        nothing
    else
        make_selector(values(generator_categories)...)
    end
end

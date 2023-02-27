"""Return a dict where keys are a tuple of input parameters (fuel, unit_type) and values are
generator types."""
function get_generator_mapping(filename = nothing)
    if isnothing(filename)
        filename = GENERATOR_MAPPING_FILE
    end
    genmap = open(filename) do file
        YAML.load(file)
    end

    mappings = Dict{NamedTuple, String}()
    for (gen_type, vals) in genmap
        for val in vals
            pm = get(val, "primemover", nothing)
            pm = isnothing(pm) ? nothing : uppercase(string(pm))
            ext = get(val, "ext_category", nothing)
            ext = isnothing(ext) ? nothing : uppercase(string(ext))
            gentype = get(val, "gentype", "Any")
            fuel = get(val, "fuel", nothing)
            key = (gentype = gentype, fuel = fuel, primemover = pm, ext = ext)
            if haskey(mappings, key)
                error(
                    "duplicate generator mappings: $gen_type $(key.gentype) $(key.fuel) $(key.primemover) $(key.ext)",
                )
            end
            mappings[key] = gen_type
        end
    end

    return mappings
end

"""Return the generator category for this fuel and unit_type."""
function get_generator_category(
    gentype,
    fuel,
    primemover,
    ext,
    mappings::Dict{NamedTuple, String},
)
    fuel = isnothing(fuel) ? nothing : uppercase(string(fuel))
    primemover = isnothing(primemover) ? nothing : uppercase(string(primemover))
    generator = nothing
    ext = isnothing(ext) ? nothing : uppercase(ext)

    # Try to match the primemover if it's defined. If it's nothing then just match on fuel.
    for t in InteractiveUtils.supertypes(gentype),
        pm in (primemover, nothing),
        f in (fuel, nothing),
        ext in (ext, nothing)

        key = (gentype = string(nameof(t)), fuel = f, primemover = pm, ext = ext)
        if haskey(mappings, key)
            generator = mappings[key]
            break
        end
    end

    if isnothing(generator)
        @error "No mapping defined for generator type=$gentype fuel=$fuel primemover=$primemover ext=$ext"
    end

    return generator
end

"""
    generators = make_fuel_dictionary(system::PSY.System, mapping::Dict{NamedTuple, String})

This function makes a dictionary of fuel type and the generators associated.

# Arguments
- `sys::PSY.System`: the system that is used to create the results
- `results::IS.Results`: results

# Key Words
- `categories::Dict{String, NamedTuple}`: if stacking by a different category is desired

# Example
results = solve_op_model!(OpModel)
generators = make_fuel_dictionary(sys)

"""
function make_fuel_dictionary(sys::PSY.System, mapping::Dict{NamedTuple, String})
    generators = PSY.get_components(PSY.get_available, PSY.StaticInjection, sys)
    gen_categories = Dict()
    for category in unique(values(mapping))
        gen_categories["$category"] = []
    end
    gen_categories["Load"] = []

    for gen in generators
        if gen isa PSY.ElectricLoad
            category = "Load"
        else
            fuel = hasmethod(PSY.get_fuel, Tuple{typeof(gen)}) ? PSY.get_fuel(gen) : nothing
            pm =
                hasmethod(PSY.get_prime_mover, Tuple{typeof(gen)}) ?
                PSY.get_prime_mover(gen) : nothing
            ext = get(PSY.get_ext(gen), "ext_category", nothing)
            category = get_generator_category(typeof(gen), fuel, pm, ext, mapping)
        end
        push!(gen_categories["$category"], (string(nameof(typeof(gen))), PSY.get_name(gen)))
    end
    [delete!(gen_categories, "$k") for (k, v) in gen_categories if isempty(v)]
    return gen_categories
end

function make_fuel_dictionary(sys::PSY.System; kwargs...)
    mapping = get_generator_mapping(get(kwargs, :generator_mapping_file, nothing))
    return make_fuel_dictionary(sys, mapping)
end

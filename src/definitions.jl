
NEGATIVE_PARAMETERS = [PSY.PowerLoad]
SUPPORTED_CURTAILMENT_PARAMETERS = [PSI.ActivePowerTimeSeriesParameter]

SUPPORTED_CURTAILMENT_VARIABLES = [PSI.ActivePowerVariable]
SUPPORTED_LOAD_VARIABLES = [PSI.ActivePowerVariable]
SUPPORTED_STORAGE_VARIABLES = [PSI.ActivePowerInVariable, PSI.ActivePowerOutVariable]
SUPPORTED_SERVICE_VARIABLES = [PSI.ActivePowerReserveVariable]

SUPPORTED_OVERGENERATION_VARIABLE = PSI.SystemBalanceSlackDown
SUPPORTED_UNSERVEDENERGY_VARIABLES = PSI.SystemBalanceSlackUp
BALANCE_SLACKVARS = Dict(
    SUPPORTED_OVERGENERATION_VARIABLE => "Over Generation",
    SUPPORTED_UNSERVEDENERGY_VARIABLES => "Unserved Energy",
)

LOAD_RENAMING = Dict(
    :ActivePowerTimeSeriesParameter__PowerLoad => :Load,
    :ActivePowerVariable__PowerLoad => :Dispatchable_Load,
)

GENERATOR_MAPPING_FILE = joinpath(
    dirname(dirname(pathof(PowerAnalytics))),
    "deps",
    "generator_mapping.yaml",
)

# Color Definitions
PALETTE_FILE = joinpath(
    dirname(dirname(pathof(PowerAnalytics))),
    "deps",
    "color-palette.yaml",
)

struct PaletteColor
    category::AbstractString
    RGB::AbstractString
    color::Colors.RGBA{Float64}
    order::Int64
end

function PaletteColor(category::String, RGB::String, order::Int64)
    rgba =
        parse.(Int64, strip.(split(strip(RGB, ['r', 'g', 'b', 'a', '(', ')', ' ']), ",")))
    color = Colors.RGBA(rgba[1] / 288, rgba[2] / 288, rgba[3] / 288, rgba[4])
    return PaletteColor(category, RGB, color, order)
end

function get_palette(file = nothing)
    file = isnothing(file) ? PALETTE_FILE : file
    palette_config = YAML.load_file(file)
    palette_colors = []
    for (k, v) in palette_config
        push!(palette_colors, PaletteColor(k, v["RGB"], v["order"]))
    end
    sort!(palette_colors, by = x -> x.order)
    return palette_colors
end
function get_default_palette()
    default_palette = []
    palette = get_palette()
    default_order = [6, 52, 14, 1, 32, 7, 18, 20, 27, 53, 17] # the default order from the color palette #
    for i in default_order
        for p in palette
            if p.order == i
                push!(default_palette, p)
            end
        end
    end
    return default_palette
end

# Recursively find all subtypes: useful for categorizing variables
function all_subtypes(t::Type)
    st = [t]
    for t in st
        union!(st, InteractiveUtils.subtypes(t))
    end
    return [split(string(s), ".")[end] for s in st]
end

FUEL_DEFAULT = getfield.(get_palette(), :color)
CATEGORY_DEFAULT = getfield.(get_palette(), :category)


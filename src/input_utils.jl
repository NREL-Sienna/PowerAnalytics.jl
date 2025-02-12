# LOADING RESULTS
"""
Accept a directory that contains several results subdirectories (that each contain
`results`, `problems`, etc. sub-subdirectories) and construct a sorted dictionary from
`String` to `SimulationProblemResults` where the keys are the subdirectory names and the
values are loaded results datasets.

# Arguments
 - `results_dir::AbstractString`: the directory where results subdirectories can be found
 - `problem::String`: the name of the problem to load (e.g., "UC", "ED")
 - `scenarios::Union{Vector{AbstractString}, Nothing} = nothing`: a list of scenario
   subdirectories to load, or `nothing` to load all the subdirectories
 - `kwargs...`: keyword arguments to pass through to
   `get_decision_problem_results`
"""
function create_problem_results_dict(
    results_dir::AbstractString,
    problem::String,
    scenarios::Union{Vector{<:AbstractString}, Nothing} = nothing;
    populate_system::Bool = false,
    kwargs...,
)
    if scenarios === nothing
        scenarios = filter(x -> isdir(joinpath(results_dir, x)), readdir(results_dir))
    end
    return SortedDict(
        scenario => PSI.get_decision_problem_results(
            PSI.SimulationResults(joinpath(results_dir, scenario)),
            problem; populate_system = populate_system, kwargs...) for scenario in scenarios
    )
end

# READING KEYS FROM RESULTS
# TODO move `DATETIME_COL` to PowerSimulations to replace its hardcoding of :DateTime
"Name of the column that represents the time axis in computed DataFrames"
const DATETIME_COL = "DateTime"

"Name of a column that represents whole-of-`System` data"
const SYSTEM_COL = "System"

"The various key entry types that can work with a System"
const SystemEntryType = Union{
    PSI.VariableType,
    PSI.ExpressionType,
}

"The various key entry types that can be used to make a PSI.OptimizationContainerKey"
const EntryType = Union{
    SystemEntryType,
    PSI.ParameterType,
    PSI.AuxVariableType,
    PSI.InitialConditionType,
}

# TODO: put make_key in PowerSimulations and refactor existing code to use it
"Create a PSI.OptimizationContainerKey from the given key entry type and component.

# Arguments
 - `entry::Type{<:EntryType}`: the key entry
 - `component` (`::Type{<:Union{Component, PSY.System}}` or `::Type{<:Component}` depending
   on the key type): the component type
"
function make_key end
make_key(entry::Type{<:PSI.VariableType}, component::Type{<:Union{Component, PSY.System}}) =
    PSI.VariableKey(entry, component)
make_key(entry::Type{<:PSI.ExpressionType}, comp::Type{<:Union{Component, PSY.System}}) =
    PSI.ExpressionKey(entry, comp)
make_key(entry::Type{<:PSI.ParameterType}, component::Type{<:Component}) =
    PSI.ParameterKey(entry, component)
make_key(entry::Type{<:PSI.AuxVariableType}, component::Type{<:Component}) =
    PSI.AuxVarKey(entry, component)
make_key(entry::Type{<:PSI.InitialConditionType}, component::Type{<:Component}) =
    PSI.ICKey(entry, component)

"Sort a vector of key tuples into variables, parameters, etc. like PSI.load_results! wants"
make_entry_kwargs(key_tuples::Vector{<:Tuple}) = [
    (key_name => filter(((this_key, _),) -> this_key <: key_type, key_tuples))
    for (key_name, key_type) in [
        (:variables, PSI.VariableType),
        (:duals, PSI.ConstraintType),
        (:parameters, PSI.ParameterType),
        (:aux_variables, PSI.AuxVariableType),
        (:expressions, PSI.ExpressionType),
    ]
]

# SimulationProblemResults has some extra features: the ability to `load_results!` and to specify which columns we want
function _read_results_with_keys_wrapper(
    res::PSI.SimulationProblemResults,
    key_pair;
    start_time::Union{Nothing, DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
    cols::Union{Colon, Vector{String}},
)
    cache_len = isnothing(len) ? length(PSI.get_timestamps(res)) : len
    PSI.load_results!(
        res,
        cache_len;
        initial_time = start_time,
        make_entry_kwargs([key_pair])...,
    )
    return PSI.read_results_with_keys(
        res,
        [make_key(key_pair...)];
        start_time = start_time,
        len = len,
        cols = cols,
    )
end

# Otherwise here is the fallback
_read_results_with_keys_wrapper(
    res::IS.Results,
    key_pair;
    start_time::Union{Nothing, DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
    cols::Union{Colon, Vector{String}},
) =
    PSI.read_results_with_keys(
        res,
        [make_key(key_pair...)];
        start_time = start_time,
        len = len,
    )

"Given an EntryType and a Component, fetch a single column of results"
function read_component_result(res::IS.Results, entry::Type{<:EntryType}, comp::Component;
    start_time::Union{Nothing, DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    key_pair = (entry, typeof(comp))
    res = try
        only(
            values(
                _read_results_with_keys_wrapper(
                    res,
                    key_pair;
                    start_time = start_time,
                    len = len,
                    cols = [get_name(comp)],
                ),
            ),
        )
    catch e
        if e isa KeyError && e.key == get_name(comp)
            throw(
                NoResultError(
                    "$(get_name(comp)) not in the results for $(PSI.encode_key_as_string(make_key(key_pair...)))",
                ),
            )
        else
            rethrow(e)
        end
    end
    return res[!, [DATETIME_COL, get_name(comp)]]
end

# TODO caching here too
"Given an EntryType that applies to the System, fetch a single column of results"
function read_system_result(res::IS.Results, entry::Type{<:SystemEntryType};
    start_time::Union{Nothing, DateTime} = nothing, len::Union{Int, Nothing} = nothing)
    key = make_key(entry, PSY.System)
    res = only(
        values(PSI.read_results_with_keys(
                res,
                [key];
                start_time = start_time,
                len = len,
            )),
    )
    @assert size(res, 2) == 2 "Expected a time column and a data column in the results for $(PSI.encode_key_as_string(key)), got $(size(res, 2)) columns"
    @assert DATETIME_COL in names(res) "Expected a column named $DATETIME_COL in the results for $(PSI.encode_key_as_string(key)), got $(names(res))"
    # Whatever the non-time column is, rename it to something standard
    res = DataFrames.rename(res, findfirst(!=(DATETIME_COL), names(res)) => SYSTEM_COL)
    return res[!, [DATETIME_COL, SYSTEM_COL]]
end

# TODO should this be defined in PSI (or not at all)?
get_system_uuid(results::PSI.SimulationProblemResults) = results.system_uuid

"Read from disk the System associated with the given SimulationProblemResults"
function read_serialized_system(results::PSI.SimulationProblemResults)
    sys_filename = "system-$(get_system_uuid(results)).json"
    sys_path = joinpath(
        PSI.get_execution_path(results),
        "problems",
        PSI.get_model_name(results),
        sys_filename,
    )
    return PowerSystems.System(sys_path)
end

# TODO should this just replace PSI.get_decision_problem_results?
"""
Wrapper around PSI.get_decision_problem_results that can also set the system using
read_serialized_system and populate the units system.

# Arguments
 - `sim_results::PSI.SimulationResults`: the simulation results to read from
 - `problem::String`: the name of the problem (e.g., "UC", "ED")
 - `populate_system::Bool`: whether to set the results' system using read_serialized_system
 - `populate_units::Union{IS.UnitSystem, String, Nothing} = IS.UnitSystem.NATURAL_UNITS`:
   the units system with which to populate the results' system, if any (requires
   populate_system=true)
"""
function get_populated_decision_problem_results(
    sim_results::PSI.SimulationResults,
    problem::String;
    populate_system::Bool = true,
    populate_units::Union{IS.UnitSystem, String, Nothing} = IS.UnitSystem.NATURAL_UNITS,
)
    results = PSI.get_decision_problem_results(sim_results, problem)
    populate_system && PSI.set_system!(results, read_serialized_system(results))
    (populate_units === nothing) ||
        PSY.set_units_base_system!(PSI.get_system(results), populate_units)
    return results
end

"""
Accept a directory that contains several results subdirectories (that each contain
`results`, `problems`, etc. sub-subdirectories) and construct a sorted dictionary from
String to SimulationProblemResults where the keys are the subdirectory names and the values
are loaded results datasets with (by default) attached systems.

# Arguments
 - `results_dir::AbstractString`: the directory where results subdirectories can be found
 - `problem::String`: the name of the problem to load (e.g., "UC", "ED")
 - `scenarios::Union{Vector{AbstractString}, Nothing} = nothing`: a list of scenario
   subdirectories to load, or `nothing` to load all the subdirectories
 - `kwargs...`: keyword arguments to pass through to
   [`get_populated_decision_problem_results`](@ref)
"""
function create_problem_results_dict(
    results_dir::AbstractString,
    problem::String,
    scenarios::Union{Vector{<:AbstractString}, Nothing} = nothing;
    kwargs...,
)
    if scenarios === nothing
        scenarios = filter(x -> isdir(joinpath(results_dir, x)), readdir(results_dir))
    end
    return SortedDict(
        scenario => get_populated_decision_problem_results(
            PSI.SimulationResults(joinpath(results_dir, scenario)),
            problem; kwargs...) for scenario in scenarios
    )
end

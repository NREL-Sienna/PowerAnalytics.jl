

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
   [`PSI.get_decision_problem_results`](@ref)
"""
function create_problem_results_dict(
    results_dir::AbstractString,
    problem::String,
    scenarios::Union{Vector{<:AbstractString}, Nothing} = nothing;
    populate_system::Bool=false,
    kwargs...,
)
    if scenarios === nothing
        scenarios = filter(x -> isdir(joinpath(results_dir, x)), readdir(results_dir))
    end
    return SortedDict(
        scenario => PSI.get_decision_problem_results(
            PSI.SimulationResults(joinpath(results_dir, scenario)),
            problem; populate_system=populate_system, kwargs...) for scenario in scenarios
    )
end

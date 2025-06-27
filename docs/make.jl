using Documenter
using PowerAnalytics
import DataStructures: OrderedDict
using DocumenterInterLinks
using Dates

ENV["GKSwstype"] = "100"  # Prevent GR from opening gksqt GUI

links = InterLinks(
    "Julia" => "https://docs.julialang.org/en/v1/",
    "InfrastructureSystems" => "https://nrel-sienna.github.io/InfrastructureSystems.jl/stable/",
    "PowerSystems" => "https://nrel-sienna.github.io/PowerSystems.jl/stable/",
    "PowerSimulations" => "https://nrel-sienna.github.io/PowerSimulations.jl/stable/",
    "StorageSystemsSimulations" => "https://nrel-sienna.github.io/StorageSystemsSimulations.jl/stable/",
    "HydroPowerSimulations" => "https://nrel-sienna.github.io/HydroPowerSimulations.jl/dev/",
)

pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Tutorials" => Any[
        "Simulation Scenarios Analysis" => "tutorials/PA_workflow_tutorial.md",
    ],
    # TODO flesh out the how-tos, explanation
    # "How to..." => Any[#="stub" => "how_to_guides/stub.md"=#],
    # "Explanation" => Any[#="stub" => "explanation/stub.md"=#],
    "Reference" => Any[ 
        "Public API" => "reference/public.md",
        "Developers" => ["Developer Guidelines" => "reference/developer_guidelines.md",
        "Internals" => "reference/internal.md"]]
     
)

# Run simulation scenarios for RTS-GMLC Tutorial
include(joinpath(@__DIR__, "src", "tutorials", "_run_scenarios_RTS_Tutorial.jl"))


makedocs(
    modules = [PowerAnalytics],
    format = Documenter.HTML(
        prettyurls = haskey(ENV, "GITHUB_ACTIONS"),
        size_threshold = nothing,),
    sitename = "PowerAnalytics.jl",
    authors = "Gabriel Konar-Steenberg and Clayton Barrows",
    pages = Any[p for p in pages],
    draft = false,
    plugins = [links]
)


deploydocs(
    repo= "github.com/NREL-Sienna/PowerAnalytics.jl",
    target="build",
    branch="gh-pages",
    devbranch="main",
    devurl="dev",
    push_preview=true,
    versions=["stable" => "v^", "v#.#"],
)
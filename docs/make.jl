using Documenter
using PowerAnalytics
import DataStructures: OrderedDict


pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Tutorials" => Any["stub" => "tutorials/stub.md"],
    "How to..." => Any["stub" => "how_to_guides/stub.md"],
    "Explanation" => Any["stub" => "explanation/stub.md"],
    "Reference" => Any[ 
        "Public API" => "reference/public.md",
        "Developers" => ["Developer Guidelines" => "reference/developer_guidelines.md",
        "Internals" => "reference/internal.md"]]
     
)


makedocs(
    modules = [PowerAnalytics],
    format = Documenter.HTML(
        prettyurls = haskey(ENV, "GITHUB_ACTIONS"),
        size_threshold = nothing,),
    sitename = "PowerAnalytics.jl",
    authors = "Gabriel Konar-Steenberg and Clayton Barrows",
    pages = Any[p for p in pages],
    draft = false,
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

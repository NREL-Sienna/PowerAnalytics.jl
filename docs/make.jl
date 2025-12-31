using Documenter
using PowerAnalytics
import DataStructures: OrderedDict
using DocumenterInterLinks
using Dates
using Literate

ENV["GKSwstype"] = "100"  # Prevent GR from opening gksqt GUI

links = InterLinks(
    "Julia" => "https://docs.julialang.org/en/v1/",
    "InfrastructureSystems" => "https://nrel-sienna.github.io/InfrastructureSystems.jl/stable/",
    "PowerSystems" => "https://nrel-sienna.github.io/PowerSystems.jl/stable/",
    "PowerSimulations" => "https://nrel-sienna.github.io/PowerSimulations.jl/stable/",
    "StorageSystemsSimulations" => "https://nrel-sienna.github.io/StorageSystemsSimulations.jl/stable/",
    "HydroPowerSimulations" => "https://nrel-sienna.github.io/HydroPowerSimulations.jl/dev/",
)

# Function to clean up old generated files
function clean_old_generated_files(dir::String; remove_all_md::Bool=false)
    if !isdir(dir)
        @warn "Directory does not exist: $dir"
        return
    end
    if remove_all_md
        generated_files = filter(f -> endswith(f, ".md"), readdir(dir))
    else
        generated_files = filter(f -> startswith(f, "generated_") && endswith(f, ".md"), readdir(dir))
    end
    for file in generated_files
        rm(joinpath(dir, file), force=true)
        @info "Removed old generated file: $file"
    end
end

# Function to add download links to generated markdown
function add_download_links(content, jl_file, ipynb_file)
    download_section = """

*To follow along, you can download this tutorial as a [Julia script (.jl)](../$(jl_file)) or [Jupyter notebook (.ipynb)]($(ipynb_file)).*

"""
    m = match(r"^(#+ .+)$"m, content)
    if m !== nothing
        heading = m.match
        content = replace(content, r"^(#+ .+)$"m => heading * download_section, count=1)
    end
    return content
end

# Process tutorials with Literate
# Exclude helper scripts that start with "_"
tutorial_files = filter(x -> occursin(".jl", x) && !startswith(x, "_"), readdir("docs/src/tutorials"))
if !isempty(tutorial_files)
    tutorial_outputdir = joinpath(pwd(), "docs", "src", "tutorials", "generated")
    clean_old_generated_files(tutorial_outputdir; remove_all_md=true)
    mkpath(tutorial_outputdir)
    
    for file in tutorial_files
        @show file
        infile_path = joinpath(pwd(), "docs", "src", "tutorials", file)
        execute = occursin("EXECUTE = TRUE", uppercase(readline(infile_path))) ? true : false
        execute && include(infile_path)
        
        outputfile = replace("$file", ".jl" => "")
        
        # Generate markdown
        Literate.markdown(infile_path,
                          tutorial_outputdir;
                          name = outputfile,
                          credit = false,
                          flavor = Literate.DocumenterFlavor(),
                          documenter = true,
                          postprocess = (content -> add_download_links(content, file, string(outputfile, ".ipynb"))),
                          execute = execute)
        
        # Generate notebook
        Literate.notebook(infile_path,
                          tutorial_outputdir;
                          name = outputfile,
                          credit = false,
                          execute = false)
    end
end

pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Tutorials" => Any[
        "Simulation Scenarios Analysis" => "tutorials/generated/PA_workflow_tutorial.md",
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
using Documenter
using PowerAnalytics
using Literate
using DataStructures

folders = Dict(
)

for (name, folder) in folders
    for file in folder
        outputdir = joinpath(pwd(), "docs/src/howto")
        inputfile = joinpath(pwd(), "docs/src/$name/$file")
        Literate.markdown(inputfile, outputdir)
    end
end
if isfile("docs/src/howto/.DS_Store.md")
    rm("docs/src/howto/.DS_Store.md")
end

makedocs(
    sitename="PowerAnalytics.jl",
    format=Documenter.HTML(
        mathengine=Documenter.MathJax(),
        prettyurls=get(ENV, "CI", nothing) == "true",
    ),
    modules=[PowerAnalytics],
    authors="Clayton Barrows",
    pages=Any[
        "Introduction" => "index.md",
        #"Quick Start Guide" => "qs_guide.md",
        #"Logging" => "man/logging.md",
        # "Operation Model" => "man/op_problem.md",
        # "How To" => Any[
        #     "Set Up Plots" => "howto/3.0_set_up_plots.md",
        #     "Make Stack Plots" => "howto/3.1_make_stack_plots.md",
        #     "Make Bar Plots" => "howto/3.2_make_bar_plots.md",
        #     "Make Fuel Plots" => "howto/3.3_make_fuel_plots.md",
        #     "Make Forecast Plots" => "howto/3.4_make_forecast_plots.md",
        #     "Plot Fewer Variables" => "howto/3.5_plot_fewer_variables.md",
        #     "Plot Multiple Results" => "howto/3.6_plot_multiple_results.md",
        # ],
        #"Simulation Recorder" => "man/simulation_recorder.md",
        #"Model References" => Any["Hydro Models" => "ref/hydro.md"],
        "API" => Any["PowerAnalytics" => "api/PowerAnalytics.md"],
    ],
)

deploydocs(
    repo="github.com/NREL-SIIP/PowerAnalytics.jl.git",
    target="build",
    branch="gh-pages",
    devbranch="main",
    devurl="dev",
    versions=["stable" => "v^", "v#.#"],
)

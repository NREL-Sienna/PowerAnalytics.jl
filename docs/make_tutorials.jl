using Pkg
using Literate

# Literate post-processing functions for tutorial generation

# postprocess function to insert md
function insert_md(content)
    m = match(r"APPEND_MARKDOWN\(\"(.*)\"\)", content)
    if !isnothing(m)
        md_content = read(m.captures[1], String)
        content = replace(content, r"APPEND_MARKDOWN\(\"(.*)\"\)" => md_content)
    end
    return content
end

# Function to add download links to generated markdown
function add_download_links(content, jl_file, ipynb_file)
    # Add download links at the top of the file after the first heading
    download_section = """

*To follow along, you can download this tutorial as a [Julia script (.jl)]($(jl_file)) or [Jupyter notebook (.ipynb)]($(ipynb_file)).*

"""
    # Insert after the first heading (which should be the title)
    # Match the first heading line and replace it with heading + download section
    m = match(r"^(#+ .+)$"m, content)
    if m !== nothing
        heading = m.match
        content = replace(content, r"^(#+ .+)$"m => heading * download_section, count=1)
    end
    return content
end

# Function to add Pkg.status() to notebook after first cell
function add_pkg_status_to_notebook(nb::Dict)
    cells = get(nb, "cells", [])
    if isempty(cells)
        return nb
    end
    
    # Capture Pkg.status() output at build time
    io = IOBuffer()
    Pkg.status(; io=io)
    pkg_status_output = String(take!(io))
    
    # Create markdown cell with italicized preface
    preface_cell = Dict(
        "cell_type" => "markdown",
        "metadata" => Dict(),
        "source" => ["_This tutorial has demonstrated compatibility with the package versions below. If you run into any errors, first check your package versions for consistency using `Pkg.status()`._\n"]
    )
    
    # Create markdown cell with Pkg.status() output embedded in a code block
    # Split the output into lines and format as markdown code block
    pkg_status_lines = split(pkg_status_output, '\n', keepempty=true)
    pkg_status_source = ["```\n"]
    for line in pkg_status_lines
        push!(pkg_status_source, line * "\n")
    end
    push!(pkg_status_source, "```\n")
    
    pkg_status_cell = Dict(
        "cell_type" => "markdown",
        "metadata" => Dict(),
        "source" => pkg_status_source
    )

    # Insert cells after the first cell (insert in reverse order to maintain indices)
    insert!(cells, 2, pkg_status_cell)
    insert!(cells, 1, preface_cell)
    
    nb["cells"] = cells
    return nb
end

# Function to clean up old generated files
function clean_old_generated_files(dir::String)
    if !isdir(dir)
        @warn "Directory does not exist: $dir"
        return
    end
    generated_files = filter(f -> startswith(f, "generated_") && endswith(f, ".md"), readdir(dir))
    for file in generated_files
        rm(joinpath(dir, file), force=true)
        @info "Removed old generated file: $file"
    end
end

# Process tutorials with Literate
function process_tutorials()
    # Exclude helper scripts that start with "_"
    if isdir("docs/src/tutorials")
        tutorial_files = filter(x -> occursin(".jl", x) && !startswith(x, "_"), readdir("docs/src/tutorials"))
        if !isempty(tutorial_files)
            # Clean up old generated tutorial files
            tutorial_outputdir = joinpath(pwd(), "docs", "src", "tutorials")
            clean_old_generated_files(tutorial_outputdir)
            
            for file in tutorial_files
                @show file
                infile_path = joinpath(pwd(), "docs", "src", "tutorials", file)
                execute = occursin("EXECUTE = TRUE", uppercase(readline(infile_path))) ? true : false
                execute && include(infile_path)
                
                outputfile = string("generated_", replace("$file", ".jl" => ""))
                
                # Generate markdown
                Literate.markdown(infile_path,
                                  tutorial_outputdir;
                                  name = outputfile,
                                  credit = false,
                                  flavor = Literate.DocumenterFlavor(),
                                  documenter = true,
                                  postprocess = (content -> add_download_links(insert_md(content), file, string(outputfile, ".ipynb"))),
                                  execute = execute)
                
                # Generate notebook
                Literate.notebook(infile_path,
                                  tutorial_outputdir;
                                  name = outputfile,
                                  credit = false,
                                  execute = false,
                                  postprocess = add_pkg_status_to_notebook)
            end
        end
    end
end

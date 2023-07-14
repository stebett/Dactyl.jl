module Dactyl

using REPL
using Gumbo
using Logging
using Mustache
using RecipesBase
using Hyperscript
using InteractiveUtils
using PrettyTables
using Plots
using DataFrames

@tags meta body h1 
@tags_noescape p head

const startstring = "#% "
const endstring = "#@"

mutable struct DactylBlock{T}
    id
    text
    result::T
    html
end


mutable struct DactylPage
	blocks::Dict{Int, DactylBlock}
    title
    dactyl_dir
    plot_dir
    filename 
    function DactylPage(title)
        dactyl_dir = joinpath("dactyl", title)
        plot_dir = joinpath(dactyl_dir, "plots")
        filename = joinpath(dactyl_dir, "$title.html")
        blocks = isfile(filename) ? read_html(filename) : Dict()
        mkpath(plot_dir)
        new(blocks, title, dactyl_dir, plot_dir, filename)
    end
end


"""
start_dactyl()

The `start_dactyl` function initializes the Dactyl module for interactive documentation in the REPL. It checks if the `detect_block_ast` transform is already added to the active REPL backend's AST transforms. If not, it adds the transform to the list.

# Note: This function needs to be called to enable automatic block detection and updating in the Dactyl module.

# Usage:
	- Call `start_dactyl()` before using the Dactyl module in the REPL.
"""
function start_dactyl()
	if !any(occursin.("detect_block_ast", string.(Base.active_repl_backend.ast_transforms)))
		push!(Base.active_repl_backend.ast_transforms, detect_block_ast)
	end
end


"""
detect_block(ans)

1. Check for the end of the block.
2. If the end is found, look for the start of the block.
3. If the start is found, parse the block and update the page.

# Arguments
- `ans`: The output of the last command sent to the repl.

# Returns
- Nothing, but it updates the dactylpage struct and html file
"""
function detect_block(ans)
    if !check_end()
        return
    end
    dactylpage, ok = find_dactylpage()
    if !ok 
        @warn "No DactylPage found"
        return
    end
    unformatted_text = retrive_last_block()
    block_id, block_text = parse_block(unformatted_text)
    update_page(Main.eval(dactylpage), parse(Int, block_id), block_text, ans)
end


"""
detect_block_ast(ast)

The `detect_block_ast` function is an Abstract Syntax Tree transform that wraps an input AST with the code necessary to invoke the `detect_block` function. It evaluates the `detect_block` function with the `ans` variable in the REPL environment.

# Arguments:
	- `ast`: The input AST to be transformed.

# Returns:
	- The transformed AST with the `detect_block` function invocation.
"""
detect_block_ast(ast) = :(Base.eval(Main, :(detect_block(ans))); $(ast))


"""
retrive_last_block()

Retrieves the last block from the command history.

# Returns
- The last block as a string.

"""
function retrive_last_block()
    return read_history()[1:find_last_start()]
end

"""
read_history()

Reads the command history from the REPL.

# Returns
- An array of strings representing the command history.

"""
function read_history()
    h = reverse(readlines(REPL.find_hist_file()))[1:end]
    h1 = filter(!contains("# mode:"), h)
    h2 = filter(!contains("# time:"), h1)
	return strip.(h2)
end

"""
find_last_start()

Finds the position of the last startstring in the command history.

# Returns
- The position of the last startstring.

"""
function find_last_start()
    return first(findall(occursin.(startstring, read_history())))
end

"""
check_end()

Checks if the endstring is present in the command history.

# Returns
- `true` if the endstring is found, `false` otherwise.

"""
function check_end()
    return occursin(endstring, first(read_history()))
end

"""
find_dactylpage()

Finds the DactylPage object in the current scope.

# Returns
- A tuple with the name of the DactylPage object and a boolean indicating if it was found.

"""
function find_dactylpage()
    variables = names(Main)
    for v in variables
        try
            if typeof(Main.eval(v)) <: DactylPage
                return v, true
            end
        catch
            @warn "Variable $v not found"
        end
    end
    return nothing, false
end

"""
parse_block(block_text)

Parses the block text.

# Arguments
- `block_text`: The text of the block.

# Returns
- The block ID and the formatted block text.

"""
function parse_block(block_text)
    text = block_text
    block_id = split(pop!(text), " ") |> last
    popfirst!(text)
	text = join(reverse(text), " <br/>")
    return block_id, text
end

"""
update_page(page, block_id, text, result)

Updates the page with the block information.

# Arguments
- `page`: The DactylPage object.
- `block_id`: The ID of the block.
- `text`: The formatted block text.
- `result`: The result of the block.

"""
function update_page(page, block_id, text, result)
    block = DactylBlock(block_id, text, result, "")
    render_block(block, page)
    page.blocks[block_id] = block
    write_html(page)
end

"""
write_html(page)

Writes the HTML file for the page.

# Arguments
- `page`: The DactylPage object.

"""
function write_html(page)
    sorted_blocks = sort(collect(page.blocks), by = x->x[1], rev=true)
    style_path = joinpath(dirname(dirname(pathof(Dactyl))), "templates", "style.css")
    link = "<link rel='stylesheet' href='$style_path'>"
    doc = [head(meta(charset="UTF-8"), link)
           body([h1(page.title), p.(getfield.(getfield.(sorted_blocks, :second), :html))])]
    savehtml(page.filename, doc)
    # reload_surf()
end

function read_html(filename)
    parsed_html = parsehtml(read(filename, String))
    html_body = parsed_html.root.children[2].children
    blocks_raw = filter(x -> typeof(x) <: HTMLElement{:div}, html_body)
    blocks = filter(x -> x.attributes == Dict("class" => "block-container"), blocks_raw)
    dactylblocks = map(blocks) do block
        tit = filter(x -> typeof(x) <: HTMLElement{:h2}, block.children)
        tit = filter(x -> haskey(x.attributes, "id"), tit) |> first
        id = tit.attributes["id"]
        parse(Int, id) => DactylBlock(id, "", "", string(block))
    end
    return Dict(dactylblocks)
end



"""
render_block(block::DactylBlock{<:Any}, page)

Renders the block as HTML.

# Arguments
- `block`: The DactylBlock object.
- `page`: The DactylPage object.

# Returns
- The HTML string representing the block.

"""
function render_block(block::DactylBlock{<:Any}, page)
    d = Dict(string(key)=>getfield(block, key) for key in fieldnames(DactylBlock))
	template_path = joinpath(dirname(dirname(pathof(Dactyl))), "templates", "block.html")
    block.html = Mustache.render_from_file(template_path, d)
end

"""
render_block(block::DactylBlock{<:AbstractPlot}, page)

Renders the block as HTML for plots.

# Arguments
- `block`: The DactylBlock object.
- `page`: The DactylPage object.

# Returns
- The HTML string representing the block.

"""
function render_block(block::DactylBlock{<:AbstractPlot}, page)
    d = Dict(string(key)=>getfield(block, key) for key in fieldnames(DactylBlock))
    d["result"] = joinpath("plots", "plot_$(block.id).png")
	savefig(block.result, joinpath(abspath(page.plot_dir), "plot_$(block.id).png"))
	template_path = joinpath(dirname(dirname(pathof(Dactyl))), "templates", "block_plot.html")
    block.html = Mustache.render_from_file(template_path, d)
end

"""
render_block(block::DactylBlock{<:Plots.Animation}, page)

Renders the block as HTML for gifs.

# Arguments
- `block`: The DactylBlock object.
- `page`: The DactylPage object.

# Returns
- The HTML string representing the block.

"""
function render_block(block::DactylBlock{<:Animation}, page)
    d = Dict(string(key)=>getfield(block, key) for key in fieldnames(DactylBlock))
    d["result"] = joinpath("plots", "plot_$(block.id).gif")
	gif(block.result, joinpath(abspath(page.plot_dir), "plot_$(block.id).gif"), fps=5)
	template_path = joinpath(dirname(dirname(pathof(Dactyl))), "templates", "block_plot.html")
    block.html = Mustache.render_from_file(template_path, d)
end

function render_block(block::DactylBlock{<:DataFrame}, page)
    d = Dict(string(key)=>getfield(block, key) for key in fieldnames(DactylBlock))
    d["result"] = p(pretty_table(HTML, d["result"]))
	template_path = joinpath(dirname(dirname(pathof(Dactyl))), "templates", "block.html")
    block.html = Mustache.render_from_file(template_path, d)
end

function render_block(block::DactylBlock{<:AbstractVector{<:AbstractPlot}}, page)
    d = Dict(string(key)=>getfield(block, key) for key in fieldnames(DactylBlock))
	plots_common_name = joinpath("plots", "plot_$(block.id)")
    img_tag(plots_common_name, i) = "<img class='block-image' src='$(plots_common_name)_$i.png'/>\n"
	result = ""
	for (i, plot) in enumerate(d["result"])
		tag = img_tag(plots_common_name, i)
		savefig(plot, joinpath(abspath(page.dactyl_dir), "$(plots_common_name)_$i.png"))
		result *= tag
	end
	d["result"] = result
	template_path = joinpath(dirname(dirname(pathof(Dactyl))), "templates", "block_scrollable_plots.html")
    block.html = Mustache.render_from_file(template_path, d)
end



"""
reload_surf()

Reloads the Surf web browser.

"""
function reload_surf()
    try
        run(`pkill -1 surf`)
        return
    catch _
        return
    end
end

export DactylPage, start_dactyl, detect_block

end # module Dactyl

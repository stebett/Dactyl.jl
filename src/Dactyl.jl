module Dactyl

using REPL
using Logging
using Mustache
using RecipesBase
using Hyperscript
using InteractiveUtils

@tags head meta body h1 
@tags_noescape p

const startstring = "#% "
const endstring = "#@"

mutable struct DactylBlock{T}
	id
	text
	result::T
end

mutable struct DactylPage
	blocks::Dict{Int, DactylBlock}
    title
    dactyl_dir
    plot_dir
    function DactylPage(title)
        dactyl_dir = joinpath("dactyl", title)
        plot_dir = joinpath(dactyl_dir, "plots")
        mkpath(plot_dir)
        new(Dict(), title, dactyl_dir, plot_dir)
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
    return block_id, join(reverse(text), " <br/>")
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
    block = DactylBlock(block_id, text, result)
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
    block_html = [render_block(b, page) for (_, b) in sorted_blocks]
    doc = [head(meta(charset="UTF-8")), body([h1(page.title), p.(block_html)])]
    savehtml(joinpath(page.dactyl_dir, "$(page.title).html"), doc)
    reload_surf()
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
    template_path = "templates/block.html"
    block_html = Mustache.render_from_file(template_path, d)
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
    d["result"] = joinpath(abspath(page.plot_dir), "plot_$(block.id).png")
    savefig(block.result, d["result"])
    template_path = "templates/block_plot.html"
    block_html = Mustache.render_from_file(template_path, d)
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

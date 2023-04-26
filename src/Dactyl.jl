module Dactyl

using REPLHistory
using RecipesBase
using Mustache
using Hyperscript
using Plots


@tags head meta body h1 
@tags_noescape p

mutable struct DactylBlock{T}
	id
	text
	result::T
end

mutable struct DactylPage
	blocks::Dict{Int, DactylBlock}
	counter::Int
	current_id
    title
    plot_dir
    function DactylPage(title)
        plot_dir = "$(title)_dactyl"
        if !isdir(plot_dir)
            mkpath(plot_dir)
        end
        new(Dict(), 0, nothing, title, plot_dir)
    end
end

function new_page(title)
    global dactylpage = DactylPage(title)
    push!(Base.active_repl_backend.ast_transforms, 
          ast -> :(Base.eval(Main, :(dactylpage.counter += 1)); $(ast)))
end

function startblock_(page, id) 
    page.counter = 0
    page.current_id = id
end

function endblock_(page, ans)
    update_page(page, ans)
end

startblock(id) = startblock_(dactylpage, id)
endblock(ans) = endblock_(dactylpage, ans)

function update_page(page, result)
    id = page.current_id
    text = replace(history(page.counter), "\n" => "<br/>")
    block = DactylBlock(id, text, result)
	page.blocks[id] = block
    write_html(page)
end

function write_html(page)
    sorted_blocks = sort(collect(page.blocks), by = x->x[1], rev=true)
    block_html = [render_block(b) for (_, b) in sorted_blocks]
    doc = [head(meta(charset="UTF-8")), body([h1(page.title), p.(block_html)])];
    savehtml(joinpath(page.plot_dir, "$(page.title).html"), doc);
    reload_surf()
end

function render_block(block::DactylBlock{<:Any})
    d = Dict(string(key)=>getfield(block, key) for key in fieldnames(DactylBlock))
    template_path = "templates/block.html"
    block_html = Mustache.render_from_file(template_path, d)
end

function render_block(block::DactylBlock{<:AbstractPlot})
    d = Dict(string(key)=>getfield(block, key) for key in fieldnames(DactylBlock))
    d["result"] = joinpath(abspath(dactylpage.plot_dir), "plot_$(block.id).png")
    savefig(block.result, d["result"])
    template_path = "templates/block_plot.html"
    block_html = Mustache.render_from_file(template_path, d)
end

"Save plots if ans is a plot and returns (ans, isplot)"

function reload_surf()
    try
        run(`pkill -1 surf`)
        return
    catch _
        return
    end
end

global dactylpage = DactylPage("prova")

export new_page, startblock, endblock, dactylpage

end # module Dactyl

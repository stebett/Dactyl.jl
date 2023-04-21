using REPLHistory
using Plots
using Mustache
using Hyperscript


@tags head meta body h1 
@tags_noescape p

mutable struct Block2
	id
	text
	ans
    isplot
end

mutable struct Page1
	blocks::Dict{Int, Block2}
	counter::Int
	current_id
    title
    plot_dir
    function Page1(title)
        plot_dir = ".$(title)_plots"
        if !isdir(plot_dir)
            mkdir(plot_dir)
        end
        new(Dict(), 0, nothing, title, plot_dir)
    end
end

function fill_block_template(block)
    d = Dict(string(key)=>getfield(block, key) for key in fieldnames(Block2))
    tpl = block.isplot ? Mustache.parse(template_plot) : Mustache.parse(template)
    block_html = Mustache.render(tpl, d)
end



function rewrite_block(page, ans)
    id = page.current_id
    result, isplot = format_ans(ans, id)
    text = replace(history(page.counter), "\n" => "<br/>")
    block = Block2(id, text, result, isplot)
	page.blocks[id] = block
    write_html(page)
end

function write_html(page)
    sorted_blocks = sort(collect(page.blocks), by = x->x[1], rev=true)
    block_html = [fill_block_template(b) for (_, b) in sorted_blocks]
    doc = [
           head(
                meta(charset="UTF-8"),
               ),
           body(
                [
                 h1(page.title),
                 p.(block_html)
                ] )
          ];
    savehtml(joinpath(page.plot_dir, "$(page.title).html"), doc);
    reload_surf()
end

function reload_surf()
    try
        run(`pkill -1 surf`)
        return
    catch _
        return
    end
end

"Save plots if ans is a plot and returns (ans, isplot)"
function format_ans(ans, id)
    if isa(ans, Plots.Plot)
        plot_name = joinpath(abspath(page.plot_dir), "plot_$id.png")
		savefig(ans, plot_name)
		isplot = true
		return plot_name, isplot
	end
	isplot = false
    # io = IOBuffer()
    # show(IOContext(io, :limit => true, :displaysize => (10, 10)), "text/html", a)
    # output = String(take!(io))
    output = ans
	return output, isplot
end

function startblock(page, id) 
    page.counter = 0
    page.current_id = id
end

endblock(page, ans) = rewrite_block(page, ans)

function f1(ast)
	# TODO: check variable page exists
    # TODO: check ast is not nothing
	:(Base.eval(Main, :(page.counter += 1)); $(ast))
end

const page = Page1("prova")
push!(Base.active_repl_backend.ast_transforms, f1)
template_path = "templates/block_content_no_plot.html"
template_plot_path = "templates/block_content.html"

template = open(template_path, "r") do file
    read(file, String)
end

template_plot = open(template_plot_path, "r") do file
    read(file, String)
end







# function repl_hook(ast)
# 	r = ""
# 	if start_block_sequence in ast #TODO proper check 
# 		id_ = extract_id(ast)
# 		r += :(Base.eval(Main, :(counter = 0))) # TODO find a way to put expressions together
# 		r += :(Base.eval(Main, :(id = id_)))
# 	elseif end_block_sequence in ast 
# 		rewrite_block(page, id, history(counter), format_ans(ans)) 
# 	end
# 	r += $(ast)
# end
# push!(Base.active_repl_backend.ast_transforms, repl_hook)




# function f2(ast)
# 	if start_block_sequence in ast
# 		:(Base.eval(Main, :(block = last(ast)); $(ast)))
# 	end
# end
	
# push!(Base.active_repl_backend.ast_transforms, f2)

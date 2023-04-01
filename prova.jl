using Plots

## 1
a = 1
b = 1
c = 8
d = 2

## 2
prova = "a"
b = "a"
c = rand(100, 100)

## 10
  
function saveans(x)
	open("/tmp/outputcontent.txt", "w") do io
		show(IOContext(io, :limit => true, :displaysize => (10, 10)), "text/plain", eval(x))
	end
	nothing
end
push!(Base.active_repl_backend.ast_transforms, saveans)


## 8
prova = 2
2

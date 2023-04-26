import Pkg; Pkg.activate(".")
using Revise
using Dactyl
using Plots
new_page("test-1")

startblock(1)
a = 1
b = 2
endblock(ans)

startblock(2)
c = 3
d = 4
endblock(ans)

c = 3
scatter(rand(100), rand(100))

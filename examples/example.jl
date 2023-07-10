julia
using Pkg
Pkg.activate("/home/ginko/phd/analysis")
Pkg.add(path="/home/ginko/dev/Dactyl")
using Dactyl

# Step 3: Initialize Dactyl
start_dactyl()

# Step 4: Define a DactylPage object
page = DactylPage("example.jl")

# Step 5: Code normally, using the predifined code separators 
#% 1
prompt = "Hello world"
new_world = "very small asteroid orbiting around Jupiter"

replace(prompt, "world"=>new_world)
#@
#% 2
using Plots
x = rand(100)
y = rand(100)

scatter(x, y)
#@

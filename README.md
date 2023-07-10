# Dactyl

Dactyl is a Julia module that enables interactive documentation within the Julia REPL. It allows you to define code blocks and automatically update an HTML page with the results of those blocks. It can be used to create dynamic tutorials, notebooks, or interactive code documentation.

## Features

- Automatic block detection: Dactyl automatically detects the start and end of code blocks in the REPL.
- Block parsing: The module parses code blocks and extracts relevant information.
- Page updating: Dactyl updates an HTML page with the parsed code blocks and their results.
- Plot rendering: Dactyl supports rendering of plots within code blocks.
- Interactive browsing: The Surf web browser can be automatically reloaded to reflect the updated HTML page.

## Usage

To use Dactyl, follow these steps:

1. Install the necessary packages by running `] add RecipesBase Logging Mustache Hyperscript`.
2. Include the Dactyl module in your code: `using Dactyl`.
3. Call the `start_dactyl()` function to initialize the Dactyl module for interactive documentation in the REPL.
4. Define a `DactylPage` object to represent the documentation page.
5. Code normally, using the predifined code separators (`#% Nblock` for start and `#@` for end)

```julia
using Dactyl

# Step 3: Initialize Dactyl
start_dactyl()

# Step 4: Define a DactylPage object
page = DactylPage("My Documentation")

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

# Step 4: Evaluate those lines in the REPL using [vim-slime](https://github.com/stebett/vim-slime-dactyl) (slightly modified to include the separator)

```

## Documentation Functions

- `start_dactyl()`: Initializes the Dactyl module for interactive documentation.
- `detect_block(ans)`: Detects code blocks, parses them, and updates the DactylPage object and HTML file.

For more details on the functions and their usage, please refer to the module code.

## Example

Check out the `examples/` directory for an example usage of the Dactyl module.

## License

Dactyl is released under the [MIT License](LICENSE).

```


-- Documentation generation script for SpaghettiCombv2
local MiniDoc = require("mini.doc")

-- Setup mini.doc with default configuration
MiniDoc.setup()

-- Define input files to process
local input_files = {
    "lua/spaghetti-comb-v2/init.lua",
}

local output_file = "doc/spaghetti-comb-v2.txt"

-- Generate the documentation
MiniDoc.generate(input_files, output_file)

print("Documentation generated successfully at " .. output_file)

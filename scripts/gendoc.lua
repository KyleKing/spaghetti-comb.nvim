-- Documentation generation script for SpaghettiComb
local MiniDoc = require('mini.doc')

-- Setup mini.doc with default configuration
MiniDoc.setup()

-- Define input files to process
local input_files = {
  'lua/spaghetti-comb/init.lua',
}

local output_file = 'doc/spaghetti-comb.txt'

-- Generate the documentation
MiniDoc.generate(input_files, output_file)

print('Documentation generated successfully at ' .. output_file)
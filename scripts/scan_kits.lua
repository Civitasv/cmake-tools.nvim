-- scripts/scan_kits.lua
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local scanner = require("cmake-tools.scanner")

local function main()
  local kits = scanner.scan_for_kits()
  print(vim.inspect(kits)) -- Use simple print in standalone
end

main()

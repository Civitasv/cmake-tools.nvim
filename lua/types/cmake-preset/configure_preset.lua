---@meta _

---@class CMakeConfigurePresetArchitecture
---@field value string?
---@field strategy ("set"|"external")?

---@class CMakeConfigurePresetToolset
---@field value string?
---@field strategy ("set"|"external")?

---@class CMakeConfigurePresetCacheVariable
---@field type string?
---@field value string|boolean

---@class CMakeConfigurePresetWarnings
---@field dev boolean?
---@field deprecated boolean?
---@field uninitialized boolean?
---@field unusedCli boolean?
---@field systemVars boolean?

---@class CMakeConfigurePresetErrors
---@field dev boolean?
---@field deprecated boolean?

---@class CMakeConfigurePresetDebug
---@field output boolean?
---@field tryCompile boolean?
---@field find boolean?

---@class CMakeConfigurePresetTrace
---@field mode ("on"|"off"|"expand")?
---@field format ("human"|"json-v1")?
---@field source string|string[]?
---@field redirect string?

---@class CMakeConfigurePreset
---@field name string
---@field hidden boolean?
---@field inherits string|string[]?
---@field condition CMakeCondition?
---@field vendor table?
---@field displayName string?
---@field description string?
---@field generator string?
---@field architecture string|CMakeConfigurePresetArchitecture?
---@field toolset string|CMakeConfigurePresetToolset?
---@field toolchainFile string?
---@field graphviz string?
---@field binaryDir string?
---@field binaryDirExpanded string?
---@field installDir string?
---@field cmakeExecutable string?
---@field cacheVariables table<string, string|boolean|CMakeConfigurePresetCacheVariable?>?
---@field environment table<string, string?>?
---@field warnings CMakeConfigurePresetWarnings?
---@field errors CMakeConfigurePresetErrors?
---@field debug CMakeConfigurePresetDebug?
---@field trace CMakeConfigurePresetTrace?
---@field disabled boolean?

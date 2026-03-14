---@meta _

---@class CMakeTestPresetOutputOpts
---@field shortProgress boolean?
---@field verbosity ("default"|"verbose"|"extra")?
---@field debug boolean?
---@field outputOnFailure boolean?
---@field quiet boolean?
---@field outputLogFile string?
---@field outputJUnitFile string?
---@field labelSummary boolean?
---@field subprojectSummary boolean?
---@field maxPassedTestOutputSize integer?
---@field maxFailedTestOutputSize integer?
---@field testOutputTruncation string?
---@field maxTestNameWidth integer?

---@class CMakeTestPresetFilterIncludeIndex
---@field start integer?
---@field end integer?
---@field stride integer?
---@field specificTests integer[]?

---@class CMakeTestPresetFilterInclude
---@field name string?
---@field label string?
---@field useUnion boolean?
---@field index CMakeTestPresetFilterIncludeIndex|string?

---@class CMakeTestPresetFilterExcludeFixtures
---@field any string?
---@field setup string?
---@field cleanup string?

---@class CMakeTestPresetFilterExclude
---@field name string?
---@field label string?
---@field fixtures CMakeTestPresetFilterExcludeFixtures?

---@class CMakeTestPresetFilter
---@field include CMakeTestPresetFilterInclude?
---@field exclude CMakeTestPresetFilterExclude?

---@class CMakeTestPresetExecutionRepeat
---@field mode "until-fail"|"until-pass"|"after-timeout"
---@field count integer

---@class CMakeTestPresetExecution
---@field stopOnFailure boolean?
---@field enableFailover boolean?
---@field jobs integer?
---@field resourceSpecFile string?
---@field testLoad integer?
---@field showOnly ("human"|"json-v1")?
---@field repeat CMakeTestPresetExecutionRepeat?
---@field interactiveDebugging boolean?
---@field scheduleRandom boolean?
---@field timeout integer?
---@field noTestsAction ("default"|"error"|"ignore")?

---@class CMakeTestPreset
---@field name string
---@field hidden boolean?
---@field inherits string|string[]?
---@field condition CMakeCondition?
---@field vendor table?
---@field displayName string?
---@field description string?
---@field environment table<string, string?>?
---@field configurePreset string?
---@field inheritConfigureEnvironment boolean?
---@field configuration string?
---@field overwriteConfigurationFile string[]?
---@field output CMakeTestPresetOutputOpts?
---@field filter CMakeTestPresetFilter?
---@field execution CMakeTestPresetExecution?
---@field disabled boolean?

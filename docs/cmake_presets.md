# CMake Presets

CMake Presets is a "standard" way in cmake to share settings with other people.

Read more about CMake presets from [CMake docs](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html).

**Attention:** Support for CMake Presets takes top priority, so if "cmake\[-user\]-presets.json" or "CMake\[User\]Presets.json" is provided, then cmake kits and cmake variants won't have any effect.

## TODO

1. [Test Preset](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#test-preset) is not supported.
2. [Package Preset](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#package-preset) is not supported.
3. [Workflow Preset](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#workflow-preset) is not supported.
4. [Condition](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#condition) mostly supported. Types `matches` and `notMatches` currently not supported due to lua's differences in regex capabilities
5. Some macros not supported yet: `$vendor{<macro-name>}`

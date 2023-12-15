# Basic usage

In the [A Basic Starting Point](https://cmake.org/cmake/help/latest/guide/tutorial/A%20Basic%20Starting%20Point.html) tutorial provided by cmake, it introduces to users how to start with cmake.

**For Configure and Build:** it uses:

```sh
mkdir Step1_build
cd Step1_build
cmake ../Step1  # Generate make system
cmake --build . # Build targets
./Tutorial      # Run targets
```

With our plugin, you can use:

```sh
CMakeGenerate # Correspond to cmake ../Step1
CMakeBuild    # Correspond to cmake --build .
CMakeRun      # Correspond to ./Tutorial

CMakeRunTest  # Correspond to ctest --test-dir <build-dir> -R xx
```

And, actually with our plugin, you no longer need to execute `generate`, `build` and `run` in a specific order, instead, you can directly run `CMakeRun` to run specific target. This plugin will automatically generate and build targets for you.

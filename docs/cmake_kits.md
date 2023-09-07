# CMake Kits

CMake Kits define rules about how to build code. Typically, a kit can include:

- A set of compilers: these are locked at specific versions so that you can switch your compiler version quickly and easily.
- A linker: you can specify linker program.
- Host and target architecture.
- A toolchain file.

To define project-specific kits, you can create a "CMakeKits.json" or "cmake-kits.json" at project root dir.

An Example:

```json
[
  {
    "name": "My Compiler Kit",

    "generator": "Ninja",

    "compilers": {
      "C": "/usr/bin/gcc",
      "CXX": "/usr/bin/g++",
      "Fortran": "/usr/bin/gfortran"
    },
    "linker": "/usr/bin/lld",
    "toochainFile": "xxx"
  },
  {
    "name": "VS 17 2022 amd64",
    "generator": "Visual Studio 17 2022",
    "host_architecture": "x64",
    "environmentSetupScript": "& \"C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat\"",
    "target_architecture": "x64",
    "compilers": {
      "C": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin/Hostx64/x64/cl.exe",
      "CXX": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.34.31933/bin//Hostx64/x64/cl.exe"
    }
  }
]
```

Read more about cmake kits from [vscode-cmake-tools docs](https://github.com/microsoft/vscode-cmake-tools/blob/main/docs/kits.md).

## Define global kits

You can also define general global kits in somewhere. To do this, you will have to specify "cmake_kits_path" option in configuration.

## TODO

1. Kits scan is not supported.
2. Option `visualStudio` and `visualStudioArchitecture` is not supported.
3. Option `preferredGenerator` is not supported.
4. Option `cmakeSettings` is not supported.
5. Option `environmentSetupScript` is only supported in the experimental terminal mode.

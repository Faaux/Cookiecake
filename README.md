# Cookiecake 🍰

A [Cookiecutter](https://cookiecutter.readthedocs.io/) template for C++ projects. Convention over configuration. Modern CMake, vcpkg.

The build system (**Cake**) discovers your libraries and executables by convention and figures out build order from their dependencies — no manual wiring.

Opinionated. Follow the convention. You can always opt-out and do manual CMake.

## Features

- **Modern CMake** — target-based, no global state, presets via `CMakePresets.json`.
- **Convention-based building** — every folder under `code/` is one library or executable. Cake discovers them automatically.
- **Per-module dependency files** — each module lists its own dependencies in `Dependencies.cmake`. Cake aggregates these to resolve build order.
- **vcpkg integration** — external dependencies via `vcpkg.json`.
- **GTest included** — every library gets a wired-up `test/` folder.
- **Opinionated** — one way to do things.

## Project layout

```text
{{project_name}}/
├── CMakeLists.txt
├── CMakePresets.json
├── code/
│   ├── exe/                  # an executable module
│   │   ├── CMakeLists.txt
│   │   ├── Dependencies.cmake
│   │   └── src/main.cpp
│   └── lib/                  # a library module
│       ├── CMakeLists.txt
│       ├── Dependencies.cmake
│       ├── include/lib/lib.hpp
│       ├── src/lib.cpp
│       └── test/             # GTest-based tests for this module
├── infra/
│   ├── cmake/                 # toolchains, warnings, caching, telemetry
│   └── vcpkg/                 # vcpkg bootstrap helpers
├── ports/                      # custom vcpkg ports, if you need them
├── triplets/                   # custom vcpkg triplets
└── vcpkg.json
```

## The convention

- All source code lives under `code/`.
- One folder is one module — a library or an executable.
- Every module has a `Dependencies.cmake`:
  - internal deps: `cake_dep(...)`, e.g. `cake_dep(project_name.someLib)`
  - external deps: `find_package(...)`
- Cake walks `code/`, reads every `Dependencies.cmake`, resolves build order. No central manifest.

Follow the convention and Cake handles the rest.

## Getting started

```bash
# Generate a new project
cookiecutter gh:<your-org>/cookiecake

# Configure and build
cd <your-project-name>
cmake --preset gcc-debug
cmake --build --preset gcc-debug

# Run tests
ctest --preset gcc-debug
```

## Adding a new library or executable

1. Create a new folder under `code/` (e.g. `code/newlib/`).
2. Add a `CMakeLists.txt` and a `Dependencies.cmake`.
3. Declare dependencies with `cake_dep(...)` for internal modules or `find_package(...)` for external ones.
4. Declare what you are building
    - `src/` are your private files. `.c`,`.cpp` or `.cppm` for modules
    - `include/` are your public files `.h`, `.hpp`

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.30...4.3)

cake_add_library({{project_name}}.lib STATIC)
target_link_libraries({{project_name}}.lib
    PRIVATE {{project_name}}.some_other_lib
            fmt::fmt)


# Dependencies.cmake
cake_dep({{project_name}}.some_other_lib)
find_package(fmt CONFIG REQUIRED)
```

## License

Licensed under **Apache-2.0 WITH LLVM-exception**. See [`LICENSE`](./LICENSE) for details.

`infra/` is adjusted from the [Beman-Project](https://github.com/bemanproject/exemplar) and extended by me.
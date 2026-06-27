cmake_minimum_required(VERSION 3.30...4.3)

include(infra/cmake/enable-experimental-import-std.cmake)

project(
    {{cookiecutter.project_name}}
    DESCRIPTION "{{cookiecutter.description}}"
    LANGUAGES CXX
    VERSION 0.1.0
)

# [CMAKE.SKIP_TESTS]
option(
    {{cookiecutter.project_name.upper
    ()
    }}_BUILD_TESTS
    "Enable building tests and test infrastructure. Default: ${PROJECT_IS_TOP_LEVEL}. Values: { ON, OFF }."
    ${PROJECT_IS_TOP_LEVEL}
)

# [CPP.Modules]
option(
    {{cookiecutter.project_name.upper
    ()
    }}_USE_MODULES
    "Provide {{cookiecutter.project_name}}.* as a C++ module"
    ON
)

# [CPP.CompilerCache]
option(
    {{cookiecutter.project_name.upper
    ()
    }}_USE_CACHE
    "Searches for sccache and ccache"
    ON
)

include(infra/cmake/Cake.cmake)
cake_init({{cookiecutter.project_name}})

cake_add_folder(FOLDER code RECURSIVE)

cake_install_library({{cookiecutter.project_name}} TARGETS {{cookiecutter.project_name}}.exe {{cookiecutter.project_name}}.lib NAMESPACE {{cookiecutter.project_name}}::)

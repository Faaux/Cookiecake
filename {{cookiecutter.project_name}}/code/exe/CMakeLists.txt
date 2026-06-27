cmake_minimum_required(VERSION 3.30...4.3)

cake_add_executable({{cookiecutter.project_name}}.exe)

target_link_libraries(
    {{cookiecutter.project_name}}.exe
    PRIVATE {{cookiecutter.project_name}}.lib
)

#include <gtest/gtest.h>

#include <lib/lib.hpp>

namespace {
TEST({{cookiecutter.project_name}}Test,foo) {
    ASSERT_EQ(foo(), 8);
}
} // namespace

#include "test_cpp.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void TestCPP::_bind_methods() {
    ClassDB::bind_method(D_METHOD("ping"), &TestCPP::ping);
}

TestCPP::TestCPP() {}
TestCPP::~TestCPP() {}

String TestCPP::ping() {
    return "C++ is working!";
}

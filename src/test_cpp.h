#ifndef TEST_CPP_H
#define TEST_CPP_H

#include <godot_cpp/classes/node.hpp>

namespace godot {
    class TestCPP : public Node {
        GDCLASS(TestCPP, Node)
    protected:
        static void _bind_methods();
    public:
        TestCPP();
        ~TestCPP();
        String ping();
    };
}

#endif

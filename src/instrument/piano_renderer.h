#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

namespace godot {
    class PianoRenderer : public RefCounted {
        GDCLASS(PianoRenderer, RefCounted);
    protected:
        static void _bind_methods();
    public:
        static PackedByteArray render_note(int pitch, double velocity, double duration_seconds, int sample_rate);
        static PackedByteArray render_pattern(Array notes, double length_beats, double bpm, int sample_rate);
    };
}
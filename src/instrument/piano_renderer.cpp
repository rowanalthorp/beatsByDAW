#include "piano_renderer.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <godot_cpp/core/math_defs.hpp>

using namespace godot;

void PianoRenderer::_bind_methods() {
    ClassDB::bind_static_method("PianoRenderer", D_METHOD("render_note", "pitch", "velocity", "duration_seconds", "sample_rate"), &PianoRenderer::render_note);
    ClassDB::bind_static_method("PianoRenderer", D_METHOD("render_pattern", "notes", "length_beats", "bpm", "sample_rate"), &PianoRenderer::render_pattern);
}

PackedByteArray PianoRenderer::render_note(int pitch, double velocity, double duration_seconds, int sample_rate) {
    double freq = 440.0 * Math::pow(2.0, (pitch - 69) / 12.0);
    int total = (int)(duration_seconds * sample_rate);
    PackedByteArray data;
    data.resize(total * 2);
    for (int i = 0; i < total; i++) {
        double s = std::sin(Math::TAU * freq * i / sample_rate) * velocity;
        data.encode_s16(i * 2, (int16_t)(s * 32767.0));
    }
    return data;
}

PackedByteArray PianoRenderer::render_pattern(Array notes, double length_beats, double bpm, int sample_rate) {
    return render_note(60, 0.8, length_beats * 60.0 / bpm, sample_rate); // stub
}
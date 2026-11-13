#include "guitar_renderer.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/math_defs.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <cmath>
#include <vector>
#include <cstdlib>

using namespace godot;

void GuitarRenderer::_bind_methods() {
    ClassDB::bind_static_method("GuitarRenderer", D_METHOD("render_note", "pitch", "velocity", "duration_seconds", "sample_rate"), &GuitarRenderer::render_note);
    ClassDB::bind_static_method("GuitarRenderer", D_METHOD("render_pattern", "notes", "length_beats", "bpm", "sample_rate"), &GuitarRenderer::render_pattern);
}

namespace {
    constexpr double DAMPING = 0.996;
    constexpr double MASTER_GAIN = 0.5;
    constexpr double TAIL_SECONDS = 3.0;
    constexpr double MAX_NOTE_AGE = 6.0;

    // From Karplus-Strong, noise burst fed into a filtered delay
    std::vector<double> make_string(int pitch, double velocity, int sample_rate) {
        double freq = 440.0 * Math::pow(2.0, (pitch - 69) / 12.0);
        int n = std::max(2, (int)Math::round(sample_rate / freq));
        std::vector<double> delay(n);
        for (int i = 0; i < n; i++)
            delay[i] = velocity * (2.0 * std::rand() / (double)RAND_MAX - 1.0);
        return delay;
    }
}

PackedByteArray GuitarRenderer::render_note(int pitch, double velocity, double duration_seconds, int sample_rate) {
    auto string = make_string(pitch, velocity, sample_rate);
    int n = (int)string.size();
    int held = std::max(1, (int)Math::round(duration_seconds * sample_rate));
    int total = std::min(held + (int)Math::round(TAIL_SECONDS * sample_rate), (int)(MAX_NOTE_AGE * sample_rate));
    PackedByteArray data;
    data.resize(total * 2);
    for (int i = 0; i < total; i++) {
        int idx = i % n;
        double s = string[idx];
        int next = (idx + 1) % n;
        string[idx] = 0.5 * (string[idx] + string[next]) * DAMPING;
        data.encode_s16(i * 2, (int16_t)Math::round(Math::clamp(s * MASTER_GAIN, -1.0, 1.0) * 32767.0));
    }
    return data;
}

// From Karplus-Strong plucked string
PackedByteArray GuitarRenderer::render_pattern(Array notes, double length_beats, double bpm, int sample_rate) {
    double seconds_per_beat = 60.0 / bpm;

    struct Event {
        int64_t start_sample;
                int64_t pos;
              int64_t total;
        std::vector<double> string;
    };
    std::vector<Event> scheduled;
    for (int i = 0; i < notes.size(); i++) {
        Dictionary note = notes[i];
        int64_t start = (int64_t)Math::round((double)note["start"] * seconds_per_beat * sample_rate);
        int64_t held = std::max<int64_t>(1, (int64_t)Math::round((double)note["length"] * seconds_per_beat * sample_rate));
        int64_t total = std::min<int64_t>(held + (int64_t)Math::round(TAIL_SECONDS * sample_rate),
                                          (int64_t)(MAX_NOTE_AGE * sample_rate));
        scheduled.push_back({start, 0, total, make_string((int)note["pitch"], (double)note["velocity"], sample_rate)});
    }

    int64_t pattern_samples = std::max<int64_t>(1, (int64_t)Math::round(length_beats * seconds_per_beat * sample_rate));
    int64_t total_samples = pattern_samples + (int64_t)Math::round(TAIL_SECONDS * sample_rate);
    PackedByteArray data;
    data.resize((int)(total_samples * 2));

    for (int64_t i = 0; i < total_samples; i++) {
        double mixed = 0.0;
        for (Event &e : scheduled) {
            if (i < e.start_sample || e.pos >= e.total) continue;
            int n = (int)e.string.size();
            int idx = (int)(e.pos % n);
            double s = e.string[idx];
            e.string[idx] = 0.5 * (e.string[idx] + e.string[(idx + 1) % n]) * DAMPING;
            e.pos++;
            mixed += s;
        }
        data.encode_s16((int)(i * 2), (int16_t)Math::round(Math::clamp(std::tanh(mixed * MASTER_GAIN), -1.0, 1.0) * 32767.0));
    }
    return data;
}
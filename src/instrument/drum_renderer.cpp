#include "drum_renderer.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/math_defs.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <cmath>
#include <cstdlib>
#include <vector>

using namespace godot;

void DrumRenderer::_bind_methods() {
    ClassDB::bind_static_method("DrumRenderer", D_METHOD("render_note", "pitch", "velocity", "duration_seconds", "sample_rate", "transpose", "ref_pitch"), &DrumRenderer::render_note, DEFVAL(0), DEFVAL(440.0));
    ClassDB::bind_static_method("DrumRenderer", D_METHOD("render_pattern", "notes", "length_beats", "bpm", "sample_rate", "transpose", "ref_pitch"), &DrumRenderer::render_pattern, DEFVAL(0), DEFVAL(440.0));
}

namespace {
    constexpr double MASTER_GAIN = 0.7;
    constexpr double MAX_DRUM_SECONDS = 1.5;   // drums are one-shots; note length doesn't extend them

    // simplified 808-style drums from Werner et al. [22 in README]
    // pitch ranges pick the drum voice, also the lanes a step grid would use:
    // kick <= 37 (GM 35/36), snare 38-41 (GM 38/40), hihat >= 42 (GM 42/44/46)
    enum class Voice { KICK, SNARE, HIHAT };
    Voice voice_for(int pitch) {
        if (pitch <= 37) return Voice::KICK;
        if (pitch <= 41) return Voice::SNARE;
        return Voice::HIHAT;
    }

    inline double noise() { return 2.0 * std::rand() / (double)RAND_MAX - 1.0; }

    struct DrumVoice {
        Voice voice;
        double t = 0.0;
        double phase = 0.0;
        double vel = 0.0;
        int64_t total = 0;
        int64_t pos = 0;
        double prev_noise = 0.0;
    };

    DrumVoice make_voice(int pitch, double velocity, int64_t total_samples) {
        DrumVoice v;
        v.voice = voice_for(pitch);
        v.vel = velocity;
        v.total = total_samples;
        return v;
    }

    double sample_voice(DrumVoice &v, double dt) {
        v.t += dt;
        v.pos++;
        double s = 0.0;
        switch (v.voice) {
            case Voice::KICK: {
                double f = 50.0 + 100.0 * std::exp(-v.t / 0.05);
                v.phase += Math::TAU * f * dt;
                s = std::sin(v.phase) * std::exp(-v.t / 0.28);
                break;
            }
            case Voice::SNARE: {
                double tone = std::sin(Math::TAU * 180.0 * v.t) * std::exp(-v.t / 0.07);
                double snap = noise() * std::exp(-v.t / 0.11);
                s = 0.4 * tone + 0.6 * snap;
                break;
            }
            case Voice::HIHAT: {
                double n = noise();
                s = (n - v.prev_noise) * 0.5 * std::exp(-v.t / 0.04);
                v.prev_noise = n;
                break;
            }
        }
        return s * v.vel * MASTER_GAIN;
    }
}

PackedByteArray DrumRenderer::render_note(int pitch, double velocity, double duration_seconds, int sample_rate, int /*transpose*/, double /*ref_pitch*/) {
    double dt = 1.0 / sample_rate;
    int64_t total = std::min<int64_t>((int64_t)std::max(1.0, duration_seconds) * sample_rate,
                                      (int64_t)(MAX_DRUM_SECONDS * sample_rate));
    DrumVoice v = make_voice(pitch, velocity, total);
    PackedByteArray data;
    data.resize((int)(total * 2));
    for (int64_t i = 0; i < total; i++)
        data.encode_s16((int)(i * 2), (int16_t)Math::round(Math::clamp(std::tanh(sample_voice(v, dt)), -1.0, 1.0) * 32767.0));
    return data;
}

PackedByteArray DrumRenderer::render_pattern(Array notes, double length_beats, double bpm, int sample_rate, int /*transpose*/, double /*ref_pitch*/) {
    double dt = 1.0 / sample_rate;
    double seconds_per_beat = 60.0 / bpm;

    struct Event { int64_t start_sample; DrumVoice voice; };
    std::vector<Event> scheduled;
    for (int i = 0; i < notes.size(); i++) {
        Dictionary note = notes[i];
        int64_t start = (int64_t)Math::round((double)note["start"] * seconds_per_beat * sample_rate);
        int64_t total = std::max<int64_t>(1, (int64_t)Math::round((double)note["length"] * seconds_per_beat * sample_rate));
        total = std::min<int64_t>(total, (int64_t)(MAX_DRUM_SECONDS * sample_rate));
        scheduled.push_back({start, make_voice((int)note["pitch"], (double)note["velocity"], total)});
    }

    int64_t pattern_samples = std::max<int64_t>(1, (int64_t)Math::round(length_beats * seconds_per_beat * sample_rate));
    int64_t tail = (int64_t)Math::round(MAX_DRUM_SECONDS * 0.5 * sample_rate); // short tail is enough for drums
    int64_t total_samples = pattern_samples + tail;
    PackedByteArray data;
    data.resize((int)(total_samples * 2));

    for (int64_t i = 0; i < total_samples; i++) {
        double mixed = 0.0;
        for (Event &e : scheduled) {
            if (i < e.start_sample || e.voice.pos >= e.voice.total) continue;
            mixed += sample_voice(e.voice, dt);
        }
        data.encode_s16((int)(i * 2), (int16_t)Math::round(Math::clamp(std::tanh(mixed), -1.0, 1.0) * 32767.0));
    }
    return data;
}

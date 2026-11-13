#include "piano_renderer.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>        // Math::min, ::round, ::lerp, ::pow
#include <godot_cpp/core/math_defs.hpp>   // Math::TAU (already there)
#include <godot_cpp/variant/dictionary.hpp> // Dictionary note = notes[i]
#include <cmath>
#include <vector>

using namespace godot;

void PianoRenderer::_bind_methods() {
    ClassDB::bind_static_method("PianoRenderer", D_METHOD("render_note", "pitch", "velocity", "duration_seconds", "sample_rate"), &PianoRenderer::render_note);
    ClassDB::bind_static_method("PianoRenderer", D_METHOD("render_pattern", "notes", "length_beats", "bpm", "sample_rate"), &PianoRenderer::render_pattern);
}

namespace {
    constexpr int PARTIAL_COUNT =  5;
    // Same table used in GDScript: harminic ratio, amp, decay, factor
    constexpr double PARTIALS[PARTIAL_COUNT][3] = {
        {1.0, 1.00, 1.00},
        {2.0, 0.45, 0.60},
        {3.0, 0.20, 0.40},
        {4.0, 0.10, 0.28},
        {5.0, 0.05, 0.20},
    };
    constexpr double ATTACK = 0.004;
    constexpr double RELEASE = 0.07;
    constexpr double MAX_VOICE_AGE = 8.0;
    constexpr double MASTER_GAIN = 0.3;

    struct Voice {
    double freq = 0.0;
    double amps[PARTIAL_COUNT];
    double decays[PARTIAL_COUNT];
    double t = 0.0;
    double rel_t = 0.0;
    double vel = 0.0;
    bool releasing = false;
    bool dead = false;
    };

    Voice make_voice(int pitch, double velocity, double dt) {
        Voice v;
        v.freq = 440.0 * Math::pow(2.0, (pitch - 69) / 12.0);
        v.vel = velocity;
        double tau = Math::lerp(2.4, 0.5, Math::inverse_lerp(21.0, 108.0, (double)pitch));
        for (int j = 0; j < PARTIAL_COUNT; j++) {
            v.amps[j] = PARTIALS[j][1];           // vel NOT baked in — applied at output
            v.decays[j] = std::exp(-dt / (tau * PARTIALS[j][2]));
        }
        return v;
    }
    
    double sample_voice(Voice &v, double dt) {
        v.t += dt;
        double env = Math::min(v.t / ATTACK, 1.0);
        if (v.releasing) {
            v.rel_t += dt;
            env *= std::exp(-v.rel_t / RELEASE);   // exponential tail, not linear
            if (env < 0.001) v.dead = true;
        }
        if (v.t > MAX_VOICE_AGE) v.dead = true;
        double s = 0.0;
        for (int j = 0; j < PARTIAL_COUNT; j++) {
            v.amps[j] *= v.decays[j];              // decay BEFORE use
            s += v.amps[j] * std::sin(Math::TAU * v.freq * PARTIALS[j][0] * v.t);
        }
        return s * env * v.vel * MASTER_GAIN;
    }
}

PackedByteArray PianoRenderer::render_note(int pitch, double velocity, double duration_seconds, int sample_rate) {
    double dt = 1.0 / sample_rate;
    double release_seconds = RELEASE * std::log(1000.0);
    int held_samples = std::max(1, (int)Math::round(duration_seconds * sample_rate));
    int total_samples = held_samples + (int)Math::ceil(release_seconds * sample_rate);
    Voice voice = make_voice(pitch, velocity, dt);
    PackedByteArray data;
    data.resize(total_samples * 2);
    for (int i = 0; i < total_samples; i++) {
        if (i == held_samples) voice.releasing = true;
        double s = std::tanh(sample_voice(voice, dt));
        data.encode_s16(i * 2, (int16_t)Math::round(s * 32767.0));
    }
    return data;
}

PackedByteArray PianoRenderer::render_pattern(Array notes, double length_beats, double bpm, int sample_rate) {
    double dt = 1.0 / sample_rate;
    double seconds_per_beat = 60.0 / bpm;
    double release_seconds = RELEASE * std::log(1000.0);

    struct Event { int64_t start_sample; int64_t end_sample; Voice voice; };
    std::vector<Event> scheduled;
    for (int i = 0; i < notes.size(); i++) {
        Dictionary note = notes[i];
        int64_t start = (int64_t)Math::round((double)note["start"] * seconds_per_beat * sample_rate);
        int64_t held = std::max<int64_t>(1, (int64_t)Math::round((double)note["length"] * seconds_per_beat * sample_rate));
        scheduled.push_back({start, start + held, make_voice((int)note["pitch"], (double)note["velocity"], dt)});
    }

    int64_t pattern_samples = std::max<int64_t>(1, (int64_t)Math::round(length_beats * seconds_per_beat * sample_rate));
    int64_t total_samples = pattern_samples + (int64_t)Math::ceil(release_seconds * sample_rate);
    PackedByteArray data;
    data.resize((int)(total_samples * 2));

    for (int64_t i = 0; i < total_samples; i++) {
        double mixed = 0.0;
        for (Event &e : scheduled) {
            if (i < e.start_sample || e.voice.dead) continue;
            if (i >= e.end_sample) e.voice.releasing = true;
            mixed += sample_voice(e.voice, dt);
        }
        data.encode_s16((int)(i * 2), (int16_t)Math::round(std::tanh(mixed) * 32767.0));
    }
    return data;
}

#include "audio_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <limits>

using namespace godot;

void AudioEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_audio", "path"), &AudioEngine::start_audio);
    ClassDB::bind_method(D_METHOD("stop_audio"), &AudioEngine::stop_audio);
    ClassDB::bind_method(D_METHOD("is_audio_finished"), &AudioEngine::is_audio_finished);
    ClassDB::bind_method(D_METHOD("pause_audio"), &AudioEngine::pause_audio);
    ClassDB::bind_method(D_METHOD("resume_audio"), &AudioEngine::resume_audio);
    ClassDB::bind_method(D_METHOD("add_audio_source", "path"), &AudioEngine::add_audio_source);
    ClassDB::bind_method(D_METHOD("add_audio_clip", "path", "timeline_start_seconds"), &AudioEngine::add_audio_clip);
    ClassDB::bind_method(D_METHOD("set_track_volume", "track_id", "volume"), &AudioEngine::set_track_volume);
    ClassDB::bind_method(D_METHOD("start_audio_sources"), &AudioEngine::start_audio_sources);
}

AudioEngine::AudioEngine() {}

AudioEngine::~AudioEngine() {
    stop_audio();
}

int AudioEngine::start_audio(const String &path) {
    const int stop_result = stop_audio();
    if (stop_result != MA_SUCCESS) return stop_result;

    if (add_audio_source(path) < 0) return -1;
    return start_audio_sources();
}

int AudioEngine::stop_audio() {
    const ma_result result = audio_device.stop();
    audio_device.clear_tracks();
    tracks.clear();
    playback_started = false;
    return static_cast<int>(result);// godot does not jive with ma_result, so we cast to int
}

int AudioEngine::pause_audio() {
    const ma_result result = audio_device.pause();
    return static_cast<int>(result);// godot does not jive with ma_result, so we cast to int
}

int AudioEngine::resume_audio() {
    const ma_result result = audio_device.resume();
    return static_cast<int>(result);// godot does not jive with ma_result, so we cast to int
}

bool AudioEngine::is_audio_finished() const {
    return audio_device.is_finished();
}

int AudioEngine::add_audio_source(const String &path) { return add_audio_clip(path, 0.0); }
int AudioEngine::add_audio_clip(const String &path, double timeline_start_seconds) {
    if (!std::isfinite(timeline_start_seconds) || timeline_start_seconds < 0.0) return -1;
    const long double start_frame = std::round(
        static_cast<long double>(timeline_start_seconds) * 48000.0 // NOTE: This is multi by sample rate which later make dynamic
    );
    if (start_frame >= static_cast<long double>(std::numeric_limits<ma_uint64>::max())) return -1;
    if (playback_started || next_track_id == std::numeric_limits<int>::max()) return -1; // cannot add sources after playback has started
    std::string std_path = path.utf8().get_data(); // converting godot string to a standard string
    auto decoder = std::make_unique<AudioDecoder>();

    if (!decoder->load(std_path)) return -1;

    const int track_id = next_track_id++;
    auto clip = std::make_unique<AudioClip>(std::move(decoder), static_cast<ma_uint64>(start_frame));
    auto track = std::make_unique<TrackChannel>(track_id, std::move(clip));
    tracks.push_back(std::move(track));
    audio_device.add_track(tracks.back().get());
    return track_id;
}

bool AudioEngine::set_track_volume(int track_id, float volume) {
    if (playback_started) return false;
    return audio_device.set_track_volume(track_id, volume);
}

int AudioEngine::start_audio_sources() {
    if (playback_started || tracks.empty()) return -1;

    const ma_result result = audio_device.start();
    if (result != MA_SUCCESS) { stop_audio(); } 
    else { playback_started = true; }
    return static_cast<int>(result);
}
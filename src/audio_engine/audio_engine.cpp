#include "audio_engine.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void AudioEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_audio", "path"), &AudioEngine::start_audio);
    ClassDB::bind_method(D_METHOD("stop_audio"), &AudioEngine::stop_audio);
    ClassDB::bind_method(D_METHOD("is_audio_finished"), &AudioEngine::is_audio_finished);
    ClassDB::bind_method(D_METHOD("pause_audio"), &AudioEngine::pause_audio);
    ClassDB::bind_method(D_METHOD("resume_audio"), &AudioEngine::resume_audio);
    ClassDB::bind_method(D_METHOD("add_audio_source", "path"), &AudioEngine::add_audio_source);
    ClassDB::bind_method(D_METHOD("start_audio_sources"), &AudioEngine::start_audio_sources);
}

AudioEngine::AudioEngine() {}

AudioEngine::~AudioEngine() {
    stop_audio();
}

int AudioEngine::start_audio(const String &path) {
    const int stop_result = stop_audio();
    if (stop_result != MA_SUCCESS) return stop_result;

    if (!add_audio_source(path)) return -1;
    return start_audio_sources();
}

int AudioEngine::stop_audio() {
    const ma_result result = audio_device.stop();
    audio_device.clear_sources();
    audio_sources.clear();
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

bool AudioEngine::add_audio_source(const String &path) {
    if (playback_started) return false; // cannot add sources after playback has started
    std::string std_path = path.utf8().get_data(); // converting godot string to a standard string
    auto decoder = std::make_unique<AudioDecoder>();

    if (!decoder->load(std_path)) return false;

    audio_sources.push_back(std::move(decoder));
    audio_device.add_source(audio_sources.back().get());
    return true;
}

int AudioEngine::start_audio_sources() {
    if (playback_started || audio_sources.empty()) return -1;

    const ma_result result = audio_device.start();
    if (result != MA_SUCCESS) { stop_audio(); } 
    else { playback_started = true; }
    return static_cast<int>(result);
}
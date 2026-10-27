#include "audio_engine.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void AudioEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_audio"), &AudioEngine::start_audio);
    ClassDB::bind_method(D_METHOD("stop_audio"), &AudioEngine::stop_audio);
}

AudioEngine::AudioEngine() {}

AudioEngine::~AudioEngine() {}

int AudioEngine::start_audio() {
    return static_cast<int>(audio_device_.start()); // godot does not jive with ma_result, so we cast to int
}

int AudioEngine::stop_audio() {
    return static_cast<int>(audio_device_.stop());// godot does not jive with ma_result, so we cast to int
}

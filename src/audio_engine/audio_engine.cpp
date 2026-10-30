#include "audio_engine.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void AudioEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_audio", "path"), &AudioEngine::start_audio);
    ClassDB::bind_method(D_METHOD("stop_audio"), &AudioEngine::stop_audio);
    ClassDB::bind_method(D_METHOD("is_audio_finished"), &AudioEngine::is_audio_finished);
    ClassDB::bind_method(D_METHOD("pause_audio"), &AudioEngine::pause_audio);
    ClassDB::bind_method(D_METHOD("resume_audio"), &AudioEngine::resume_audio);
}

AudioEngine::AudioEngine() {}

AudioEngine::~AudioEngine() {
    stop_audio();
}

int AudioEngine::start_audio(const String &path) {
    std::string std_path = path.utf8().get_data(); // converting godot string to a standard string

    if (!audio_decoder.load(std_path)) return -1;

    audio_device.set_active_decoder(&audio_decoder);
    
    ma_result res = audio_device.start();
    if (res != MA_SUCCESS) {
        audio_decoder.close();
    }
    return static_cast<int>(res); // godot does not jive with ma_result, so we cast to int

}

int AudioEngine::stop_audio() {
    const ma_result result = audio_device.stop();
    audio_decoder.close();
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

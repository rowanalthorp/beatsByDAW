#include "audio_engine.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void AudioEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_audio", "path"), &AudioEngine::start_audio);
    ClassDB::bind_method(D_METHOD("stop_audio"), &AudioEngine::stop_audio);
}

AudioEngine::AudioEngine() {}

AudioEngine::~AudioEngine() {}

int AudioEngine::start_audio(const String &path) {
    godot::UtilityFunctions::print("C++: 1. start_audio entered");
    std::string std_path = path.utf8().get_data(); // converting godot string to a standard string
    godot::UtilityFunctions::print("C++: 2. Path converted: ", String(std_path.c_str()));

    godot::UtilityFunctions::print("C++: 3. Attempting to load decoder...");
    if (!audio_decoder.load(std_path)) return -1;

    godot::UtilityFunctions::print("C++: 4. Decoder loaded successfully");
    audio_device.set_active_decoder(&audio_decoder);
    godot::UtilityFunctions::print("C++: 5. Decoder linked to device. Starting device now...");
    
    ma_result res = audio_device.start();
    godot::UtilityFunctions::print("C++: 6. Device start returned result: ", static_cast<int>(res));
    return static_cast<int>(res); // godot does not jive with ma_result, so we cast to int

}

int AudioEngine::stop_audio() {
    audio_decoder.close();
    return static_cast<int>(audio_device.stop());// godot does not jive with ma_result, so we cast to int
}

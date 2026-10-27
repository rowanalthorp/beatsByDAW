#pragma once

#include "audio_device.h"
#include <godot_cpp/classes/node.hpp>

namespace godot {
    class AudioEngine : public Node {
        GDCLASS(AudioEngine, Node);
        protected:
            static void _bind_methods();
        private:
            AudioDevice audio_device_;
        public:
            AudioEngine();
            ~AudioEngine();
            int start_audio();
            int stop_audio();
    };
}
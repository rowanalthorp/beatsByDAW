#pragma once

#include "audio_device.h"
#include "audio_decoder.h"
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {
    class AudioEngine : public Node {
        GDCLASS(AudioEngine, Node);
        protected:
            static void _bind_methods();
        private:
            AudioDevice audio_device;
            AudioDecoder audio_decoder;
        public:
            AudioEngine();
            ~AudioEngine();
            int start_audio(const String &fp);
            int stop_audio();
            int pause_audio();
            int resume_audio();
            bool is_audio_finished() const;
    };
}
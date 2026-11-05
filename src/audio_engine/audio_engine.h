#pragma once

#include "audio_device.h"
#include "track_channel.h"
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string.hpp>
#include <memory>
#include <vector>
#include <string>

namespace godot {
    class AudioEngine : public Node {
        GDCLASS(AudioEngine, Node);
        protected:
            static void _bind_methods();
        private:
            AudioDevice audio_device;
            std::vector<std::unique_ptr<TrackChannel>> tracks;
            int next_track_id = 1;
            bool playback_started = false;
        public:
            AudioEngine();
            ~AudioEngine();
            int start_audio(const String &fp);
            int stop_audio();
            int pause_audio();
            int resume_audio();
            bool is_audio_finished() const;

            int add_audio_source(const String &fp);
            int add_audio_clip(const String &fp, double timeline_start_seconds);
            bool set_track_volume(int track_id, float volume);
            int start_audio_sources();
    };
}
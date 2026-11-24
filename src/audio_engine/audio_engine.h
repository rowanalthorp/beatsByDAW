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
            bool seek_audio(double timeline_seconds);
            double get_playback_time_seconds() const;

            int add_track();
            int add_audio_source(const String &fp);
            // A duration of -1 plays from the source offset through end of file.
            int add_audio_clip(
                const String &fp,
                double timeline_start_seconds,
                double source_offset_seconds = 0.0,
                double duration_seconds = -1.0
            ); // Note: if duration_seconds is -1, it will play to the end of the source file.
            bool add_audio_clip_to_track(
                int track_id,
                const String &fp,
                double timeline_start_seconds,
                double source_offset_seconds = 0.0,
                double duration_seconds = -1.0
            );
            bool set_track_volume(int track_id, float volume);
            int start_audio_sources();

        private:
            std::unique_ptr<AudioClip> create_audio_clip(
                const String &path,
                double timeline_start_seconds,
                double source_offset_seconds,
                double duration_seconds
            );
            TrackChannel *find_track(int track_id) const;
    };
}
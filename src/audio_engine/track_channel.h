#pragma once

#include "audio_clip.h"
#include <memory>
#include <vector>

class TrackChannel {
    public:
        explicit TrackChannel(int track_id);
        ~TrackChannel();

        int get_id() const { return id; }
        void add_clip(std::unique_ptr<AudioClip> clip);
        bool has_clips() const { return !clips.empty(); }
        void mix_frames(
            float *output,
            float *clip_buffer,
            ma_uint64 timeline_start_frame,
            ma_uint32 frame_count,
            ma_uint32 channels
        );
        bool seek_to_timeline_frame(ma_uint64 timeline_frame);
        bool is_loaded() const;
        bool is_finished() const;
        float get_volume() const { return volume; }
        void set_volume(float value);

    private:
        int id;
        std::vector<std::unique_ptr<AudioClip>> clips;
        float volume = 1.0;
};

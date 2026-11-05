#pragma once

#include "audio_clip.h"
#include <memory>

class TrackChannel {
    public:
        TrackChannel(int track_id, std::unique_ptr<AudioClip> clip);
        ~TrackChannel();

        int get_id() const { return id; }
        ma_uint64 get_timeline_start_frame() const { return clip->get_timeline_start_frame(); }
        ma_uint64 read_frames(void *buffer, ma_uint64 frame_count);
        bool is_loaded() const;
        bool is_finished() const { return finished; }
        float get_volume() const { return volume; }
        void set_volume(float value);

    private:
        int id;
        std::unique_ptr<AudioClip> clip;
        float volume = 1.0;
        bool finished = false;
};

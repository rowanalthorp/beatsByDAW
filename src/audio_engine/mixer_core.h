#pragma once

#include "track_channel.h"
#include <miniaudio.h>
#include <vector>

class MixerCore {
    public :
        MixerCore(ma_uint32 channels = 2, ma_uint32 max_chunk_frames = 1024);
        ~MixerCore();
        void add_track(TrackChannel *track);
        void clear_tracks();
        bool set_track_volume(int track_id, float volume);

        bool mix_it_groovy_style(float *output, ma_uint32 frame_count);
    private:
        ma_uint32 channels;
        ma_uint32 max_chunk_frames;
        ma_uint64 timeline_frame_cursor = 0;
        std::vector<TrackChannel *> tracks;
        std::vector<float> scratch;
};
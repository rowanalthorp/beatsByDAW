#pragma once

#include "audio_decoder.h"
#include <memory>

class AudioClip {
    public:
        AudioClip(std::unique_ptr<AudioDecoder> decoder, ma_uint64 timeline_start_frame);
        ~AudioClip();
        ma_uint64 get_timeline_start_frame() const { return timeline_start_frame; }
        ma_uint64 read_frames(void *buffer, ma_uint64 frame_count);
        bool is_loaded() const;

    private:
        std::unique_ptr<AudioDecoder> decoder;
        ma_uint64 timeline_start_frame;
};

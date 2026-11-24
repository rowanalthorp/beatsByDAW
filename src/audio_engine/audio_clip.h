#pragma once

#include "audio_decoder.h"
#include <memory>

class AudioClip {
    public:
        AudioClip(
            std::unique_ptr<AudioDecoder> decoder,
            ma_uint64 timeline_start_frame,
            ma_uint64 source_offset_frame,
            ma_uint64 duration_frames
        );
        ~AudioClip();
        ma_uint64 get_timeline_start_frame() const { return timeline_start_frame; }
        ma_uint64 get_duration_frames() const { return duration_frames; }
        ma_uint64 read_frames(void *buffer, ma_uint64 frame_count);
        void mix_frames(
            float *output,
            float *scratch,
            ma_uint64 timeline_start_frame,
            ma_uint32 frame_count,
            ma_uint32 channels
        );
        bool seek_to_timeline_frame(ma_uint64 timeline_frame);
        bool is_loaded() const;
        bool is_finished() const { return finished; }

    private:
        std::unique_ptr<AudioDecoder> decoder;
        ma_uint64 timeline_start_frame;
        ma_uint64 source_offset_frame;
        ma_uint64 duration_frames;
        ma_uint64 position_frames = 0;
        bool finished = false;
};

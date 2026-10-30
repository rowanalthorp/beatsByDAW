#pragma once

#include "audio_decoder.h"
#include <miniaudio.h>
#include <vector>

class MixerCore {
    public :
        MixerCore(ma_uint32 channels = 2, ma_uint32 max_chunk_frames = 1024);
        ~MixerCore();
        void add_source(AudioDecoder *decoder);
        void clear_sources();

        bool mix_it_groovy_style(float *output, ma_uint32 frame_count);
    private:
        ma_uint32 channels;
        ma_uint32 max_chunk_frames;
        std::vector<AudioDecoder *> sources;
        std::vector<bool> source_finished;
        std::vector<float> scratch;
};
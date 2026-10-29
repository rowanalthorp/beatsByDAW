#pragma once

#include <miniaudio.h>
#include <string>

class AudioDecoder {
    public:
        AudioDecoder();
        ~AudioDecoder();

        bool load(
            const std::string &fp,
            ma_uint32 target_sample_rate = 48000,
            ma_uint32 target_channels = 2
        );
        void close();

        ma_uint64 read_frames(void *p_buffer, ma_uint64 frame_count);

        bool is_loaded() const { return loaded; }
    private:
        bool loaded = false;
        ma_decoder decoder;
};
#pragma once

#include <miniaudio.h>
#include "audio_decoder.h"

// NOTE: ma_resutl is miniaudios restult/status type
class AudioDevice {
public:
    AudioDevice();
    ~AudioDevice();

    void set_active_decoder(AudioDecoder *decoder);
    ma_result start();
    ma_result stop();

private:
    static void data_callback(
        ma_device *device,
        void *output,
        const void *input,
        ma_uint32 frame_count
    );

    ma_device device_{};
    AudioDecoder  *active_decoder = nullptr;
    bool initialized_ = false;
};
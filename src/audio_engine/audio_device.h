#pragma once

#include <miniaudio.h>
#include "audio_decoder.h"
#include <atomic>

// NOTE: ma_resutl is miniaudios restult/status type
class AudioDevice {
public:
    AudioDevice();
    ~AudioDevice();

    void set_active_decoder(AudioDecoder *decoder);
    ma_result start();
    ma_result stop();
    bool is_finished() const { return finished.load(); }

private:
    static void data_callback(
        ma_device *device,
        void *output,
        const void *input,
        ma_uint32 frame_count
    );

    ma_device device{};
    AudioDecoder  *active_decoder = nullptr;
    bool initialized = false;
    std::atomic<bool> finished{false};
};
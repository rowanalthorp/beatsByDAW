#include "audio_device.h"

#include <cstddef>
#include <cstring>

AudioDevice::AudioDevice() = default;

AudioDevice::~AudioDevice() {
    stop();
}

ma_result AudioDevice::start() {
    if (initialized_) {
        return MA_SUCCESS;
    }

    ma_device_config config =
        ma_device_config_init(ma_device_type_playback);
    config.playback.format = ma_format_f32;
    config.playback.channels = 2; // NOTE: Make this dynamic later
    config.sampleRate = 48000; // NOTE: Make this dynamic later
    config.dataCallback = data_callback;

    ma_result result = ma_device_init(nullptr, &config, &device_);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = ma_device_start(&device_);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device_);
        return result;
    }

    initialized_ = true;
    return MA_SUCCESS;
}

ma_result AudioDevice::stop() {
    if (!initialized_) {
        return MA_SUCCESS;
    }

    const ma_result result = ma_device_stop(&device_);
    ma_device_uninit(&device_);
    initialized_ = false;
    return result;
}

void AudioDevice::data_callback(
    ma_device *device,
    void *output,
    const void *input,
    ma_uint32 frame_count
) {
    (void)input; // so the compiler does not go cray cray 

    const std::size_t sample_count =
        static_cast<std::size_t>(frame_count) * device->playback.channels;
    std::memset(output, 0, sample_count * sizeof(float));
}
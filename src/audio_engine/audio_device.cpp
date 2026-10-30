#include "audio_device.h"

#include <cstddef>
#include <cstring>

AudioDevice::AudioDevice() = default;

AudioDevice::~AudioDevice() {
    stop();
}

void AudioDevice::set_active_decoder(AudioDecoder *decoder) {
    mixer.clear_sources();
    mixer.add_source(decoder);
}
void AudioDevice::add_source(AudioDecoder *decoder) { mixer.add_source(decoder); }
void AudioDevice::clear_sources() { mixer.clear_sources(); }

ma_result AudioDevice::start() {
    if (initialized) {
        return MA_SUCCESS;
    }

    finished.store(false);

    ma_device_config config =
        ma_device_config_init(ma_device_type_playback);
    config.playback.format = ma_format_f32;
    config.playback.channels = 2; // NOTE: Make this dynamic later
    config.sampleRate = 48000; // NOTE: Make this dynamic later
    config.dataCallback = data_callback;
    config.pUserData = this; // this is so that static callback has access to AudioDevice instance
    
    ma_result result = ma_device_init(nullptr, &config, &device);
    if (result != MA_SUCCESS) {
        return result;
    }

    result = ma_device_start(&device);
    if (result != MA_SUCCESS) {
        ma_device_uninit(&device);
        return result;
    }

    initialized = true;
    return MA_SUCCESS;
}

ma_result AudioDevice::stop() {
    if (!initialized) {
        return MA_SUCCESS;
    }

    ma_result result = MA_SUCCESS;
    if (!paused) { result = ma_device_stop(&device); }

    ma_device_uninit(&device);
    initialized = false;
    paused = false;
    return result;
}

ma_result AudioDevice::pause() {
    if (!initialized || paused) {
        return MA_SUCCESS;
    }

    const ma_result result = ma_device_stop(&device);
    if (result == MA_SUCCESS) {
        paused = true;
    }
    return result;
}

ma_result AudioDevice::resume() {
    if (!initialized || !paused) {
        return MA_SUCCESS;
    }

    const ma_result result = ma_device_start(&device);
    if (result == MA_SUCCESS) {
        paused = false;
    }
    return result;
}

void AudioDevice::data_callback(
    ma_device *device,
    void *output,
    const void *input,
    ma_uint32 frame_count
) {
    (void)input; // so the compiler does not go cray cray 

    auto *audio_device = static_cast<AudioDevice *>(device->pUserData); // Imma be real this line some AI magic 🙏

    const std::size_t channels = device -> playback.channels;
    const std::size_t sample_count = static_cast<std::size_t>(frame_count) * channels;
    float *cast_output_float = static_cast<float *>(output);

    if (audio_device == nullptr) {
        std::memset(output, 0, sample_count * sizeof(float));
        return;
    }

    const bool all_sources_finished = audio_device->mixer.mix_it_groovy_style(cast_output_float, frame_count);
    audio_device->finished.store(all_sources_finished);
}
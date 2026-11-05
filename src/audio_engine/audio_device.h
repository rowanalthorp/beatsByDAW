#pragma once

#include <miniaudio.h>
#include "mixer_core.h"
#include <atomic>

// NOTE: ma_resutl is miniaudios restult/status type
class AudioDevice {
public:
    AudioDevice();
    ~AudioDevice();

    void add_track(TrackChannel *track);
    void clear_tracks();
    bool set_track_volume(int track_id, float volume);
    ma_result start();
    ma_result stop();
    ma_result pause();
    ma_result resume();
    bool is_finished() const { return finished.load(); }

private:
    static void data_callback(
        ma_device *device,
        void *output,
        const void *input,
        ma_uint32 frame_count
    );

    ma_device device{};
    MixerCore mixer{2, 1024}; // default to stereo and 1024 frames per chunk
    bool initialized = false;
    bool paused = false;
    std::atomic<bool> finished{false};
};
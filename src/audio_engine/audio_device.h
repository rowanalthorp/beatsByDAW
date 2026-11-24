#pragma once

#include <miniaudio.h>
#include "mixer_core.h"
#include <atomic>

// NOTE: ma_resutl is miniaudios restult/status type
class AudioDevice {
public:
    static constexpr ma_uint32 sample_rate = 48000;
    static constexpr ma_uint32 output_channels = 2;

    AudioDevice();
    ~AudioDevice();

    void add_track(TrackChannel *track);
    void clear_tracks();
    bool set_track_volume(int track_id, float volume);
    ma_result start();
    ma_result stop();
    ma_result pause();
    ma_result resume();
    bool seek_to_frame(ma_uint64 frame);
    ma_uint64 get_playback_position_frames() const { return mixer.get_timeline_frame(); }
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
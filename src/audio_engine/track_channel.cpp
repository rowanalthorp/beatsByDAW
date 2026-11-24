#include "track_channel.h"

#include <algorithm>
#include <cstring>
#include <utility>

TrackChannel::TrackChannel(int track_id) : id(track_id) {}

TrackChannel::~TrackChannel() {}

void TrackChannel::add_clip(std::unique_ptr<AudioClip> clip) {
    if (clip != nullptr) {
        clips.push_back(std::move(clip));
    }
}

void TrackChannel::mix_frames(
    float *output,
    float *clip_buffer,
    ma_uint64 timeline_start_frame,
    ma_uint32 frame_count,
    ma_uint32 channels
) {
    const std::size_t sample_count = static_cast<std::size_t>(frame_count) * channels;
    std::memset(output, 0, sample_count * sizeof(float));

    for (const std::unique_ptr<AudioClip> &clip : clips) {
        if (clip != nullptr) {
            clip->mix_frames(output, clip_buffer, timeline_start_frame, frame_count, channels);
        }
    }
}

bool TrackChannel::seek_to_timeline_frame(ma_uint64 timeline_frame) {
    for (const std::unique_ptr<AudioClip> &clip : clips) {
        if (clip != nullptr && !clip->seek_to_timeline_frame(timeline_frame)) {
            return false;
        }
    }
    return true;
}

bool TrackChannel::is_loaded() const {
    return std::any_of(clips.begin(), clips.end(), [](const std::unique_ptr<AudioClip> &clip) {
        return clip != nullptr && clip->is_loaded();
    });
}

bool TrackChannel::is_finished() const {
    return std::all_of(clips.begin(), clips.end(), [](const std::unique_ptr<AudioClip> &clip) {
        return clip == nullptr || clip->is_finished();
    });
}

void TrackChannel::set_volume(float value) { volume = std::clamp(value, 0.0f, 1.0f);}

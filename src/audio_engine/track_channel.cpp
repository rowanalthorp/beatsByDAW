#include "track_channel.h"

#include <algorithm>
#include <utility>

TrackChannel::TrackChannel(int track_id, std::unique_ptr<AudioClip> p_clip)
    : id(track_id), clip(std::move(p_clip)) {}

TrackChannel::~TrackChannel() {}

ma_uint64 TrackChannel::read_frames(void *buffer, ma_uint64 frame_count) {
    if (finished || !is_loaded()) {
        finished = true;
        return 0;
    }

    const ma_uint64 frames_read = clip->read_frames(buffer, frame_count);
    if (frames_read < frame_count) { finished = true; }
    return frames_read;
}

bool TrackChannel::seek_to_timeline_frame(ma_uint64 timeline_frame) {
    if (!is_loaded()) return false;

    const ma_uint64 clip_start_frame = clip->get_timeline_start_frame();
    const ma_uint64 source_frame = timeline_frame > clip_start_frame
        ? timeline_frame - clip_start_frame
        : 0;
    if (!clip->seek_to_frame(source_frame)) return false;

    finished = false;
    return true;
}

bool TrackChannel::is_loaded() const { return clip != nullptr && clip->is_loaded(); }

void TrackChannel::set_volume(float value) { volume = std::clamp(value, 0.0f, 1.0f);}

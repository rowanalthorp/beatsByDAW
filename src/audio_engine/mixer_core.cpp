#include "mixer_core.h"
#include <algorithm>
#include <cstring>

MixerCore::MixerCore(ma_uint32 p_channels, ma_uint32 p_max_chunk_frames)
    : channels(p_channels),
        max_chunk_frames(std::max<ma_uint32>(1, p_max_chunk_frames)),
        track_buffer(static_cast<std::size_t>(p_channels) * max_chunk_frames),
        clip_buffer(static_cast<std::size_t>(p_channels) * max_chunk_frames) {
}
MixerCore::~MixerCore() { clear_tracks(); }

void MixerCore::add_track(TrackChannel *track) { if (track != nullptr) { tracks.push_back(track); } }
void MixerCore::clear_tracks() {
    tracks.clear();
    timeline_frame_cursor.store(0);
}

bool MixerCore::set_track_volume(int track_id, float volume) {
    for (TrackChannel *track : tracks) {
        if (track != nullptr && track->get_id() == track_id) {
            track->set_volume(volume);
            return true;
        }
    }
    return false;
}

bool MixerCore::seek_to_timeline_frame(ma_uint64 frame) {
    for (TrackChannel *track : tracks) {
        if (track != nullptr && !track->seek_to_timeline_frame(frame)) {
            return false;
        }
    }

    timeline_frame_cursor.store(frame);
    return true;
}

bool MixerCore::mix_it_groovy_style(float *output, ma_uint32 frame_count) {
    const std::size_t sample_count = static_cast<std::size_t>(frame_count) * channels;
    std::memset(output, 0, sample_count * sizeof(float));
    const ma_uint64 block_start_frame = timeline_frame_cursor.load();

    const bool all_tracks_finished = std::all_of(
        tracks.begin(),
        tracks.end(),
        [](const TrackChannel *track) { return track == nullptr || track->is_finished(); }
    );
    if (all_tracks_finished) return true;

    ma_uint32 offset_frames = 0;
    while (offset_frames < frame_count) {
        const ma_uint32 chunk_frames = std::min(max_chunk_frames, frame_count - offset_frames);
        const std::size_t output_offset = static_cast<std::size_t>(offset_frames) * channels;
        const ma_uint64 chunk_start_frame = block_start_frame + offset_frames;

        for (TrackChannel *track : tracks) {
            if (track == nullptr || track->is_finished()) continue;

            track->mix_frames(
                track_buffer.data(),
                clip_buffer.data(),
                chunk_start_frame,
                chunk_frames,
                channels
            );
            const float volume = track->get_volume();
            const std::size_t chunk_sample_count = static_cast<std::size_t>(chunk_frames) * channels;
            for (std::size_t sample = 0; sample < chunk_sample_count; ++sample) {
                output[output_offset + sample] += track_buffer[sample] * volume;
            }
        }
        offset_frames += chunk_frames;
    }
    timeline_frame_cursor.store(block_start_frame + frame_count);

    for (const TrackChannel *track : tracks) {
        if (track != nullptr && !track->is_finished()) {
            return false; // we are returning false if any source is not yet finished playing
        }
    }
    return true;
}
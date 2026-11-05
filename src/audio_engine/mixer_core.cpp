#include "mixer_core.h"
#include <algorithm>
#include <cstring>

MixerCore::MixerCore(ma_uint32 p_channels, ma_uint32 p_max_chunk_frames)
    : channels(p_channels),
    max_chunk_frames(p_max_chunk_frames),
    scratch(static_cast<std::size_t>(p_channels) * p_max_chunk_frames) {
}
MixerCore::~MixerCore() { clear_tracks(); }

void MixerCore::add_track(TrackChannel *track) { if (track != nullptr) { tracks.push_back(track); } }
void MixerCore::clear_tracks() {
    tracks.clear();
    timeline_frame_cursor = 0;
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

bool MixerCore::mix_it_groovy_style(float *output, ma_uint32 frame_count) {
    const std::size_t sample_count = static_cast<std::size_t>(frame_count) * channels;
    std::memset(output, 0, sample_count * sizeof(float));

    ma_uint32 offset_frames = 0;
    while (offset_frames < frame_count) {
        const ma_uint32 chunk_frames = std::min(max_chunk_frames, frame_count - offset_frames);
        const std::size_t output_offset = static_cast<std::size_t>(offset_frames) * channels;
        const ma_uint64 chunk_start_frame = timeline_frame_cursor + offset_frames;
        const ma_uint64 chunk_end_frame = chunk_start_frame + chunk_frames;

        for (TrackChannel *track : tracks) {
            if (track == nullptr || track->is_finished()) continue;

            const ma_uint64 track_start_frame = track->get_timeline_start_frame();
            if (chunk_end_frame <= track_start_frame) continue;

            const ma_uint64 source_offset = chunk_start_frame < track_start_frame
                ? track_start_frame - chunk_start_frame
                : 0;
            const ma_uint64 frames_to_read = chunk_frames - source_offset;
            const ma_uint64 frames_read = track->read_frames(scratch.data(), frames_to_read);
            const float volume = track->get_volume();
            std::size_t frame = 0;
            for (; frame < static_cast<std::size_t>(frames_read); ++frame) {
                const std::size_t sample_offset = frame * channels;
                ma_uint32 channel = 0;
                for (; channel < channels; ++channel) {
                    const std::size_t track_sample_offset =
                        output_offset + static_cast<std::size_t>(source_offset) * channels + sample_offset;
                    output[track_sample_offset + channel] += scratch[sample_offset + channel] * volume;
                }
            }
        }
        offset_frames += chunk_frames;
    }
    timeline_frame_cursor += frame_count;

    for (const TrackChannel *track : tracks) {
        if (track != nullptr && !track->is_finished()) {
            return false; // we are returning false if any source is not yet finished playing
        }
    }
    return true;
}
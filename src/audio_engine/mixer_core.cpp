#include "mixer_core.h"
#include <algorithm>
#include <cstring>

MixerCore::MixerCore(ma_uint32 p_channels, ma_uint32 p_max_chunk_frames)
    : channels(p_channels),
    max_chunk_frames(p_max_chunk_frames),
    scratch(static_cast<std::size_t>(p_channels) * p_max_chunk_frames) {
}
MixerCore::~MixerCore() { clear_sources(); }

void MixerCore::add_source(AudioDecoder *decoder) { if (decoder != nullptr) { sources.push_back(decoder); source_finished.push_back(false); } }
void MixerCore::clear_sources() { sources.clear(); source_finished.clear(); }

bool MixerCore::mix_it_groovy_style(float *output, ma_uint32 frame_count) {
    const std::size_t sample_count = static_cast<std::size_t>(frame_count) * channels;
    std::memset(output, 0, sample_count * sizeof(float));

    ma_uint32 offset_frames = 0;
    while (offset_frames < frame_count) {
        const ma_uint32 chunk_frames = std::min(max_chunk_frames, frame_count - offset_frames);
        std::size_t source_i = 0;
        for (; source_i < sources.size(); ++source_i) {
            AudioDecoder *decoder = sources[source_i];
            if (decoder != nullptr && decoder->is_loaded() && !source_finished[source_i]) {
                const ma_uint64 frames_read = decoder->read_frames(scratch.data(), chunk_frames);
                const std::size_t frames_to_mix = static_cast<std::size_t>(frames_read);
                const std::size_t offset_to_mix = static_cast<std::size_t>(offset_frames);

                ma_uint32 i = 0;
                for (; i < frames_to_mix * channels; ++i) {
                    output[i + offset_to_mix * channels] += scratch[i];
                }
                if (frames_read < chunk_frames) {
                    source_finished[source_i] = true;
                }
            } else if (decoder == nullptr || !source_finished[source_i]) {
                source_finished[source_i] = true;
            }
        }
        offset_frames += chunk_frames;
    }
    std::size_t i = 0;
    for (; i < source_finished.size(); ++i) {
        if (!source_finished[i]) {
            return false; // we are returning false if any source is not yet finished playing
        }
    }
    return true;
}
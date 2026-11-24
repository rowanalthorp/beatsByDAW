#include "audio_clip.h"

#include <algorithm>
#include <cstddef>
#include <cstring>
#include <limits>
#include <utility>

AudioClip::AudioClip(
    std::unique_ptr<AudioDecoder> p_decoder,
    ma_uint64 p_timeline_start_frame,
    ma_uint64 p_source_offset_frame,
    ma_uint64 p_duration_frames
) : decoder(std::move(p_decoder)),
      timeline_start_frame(p_timeline_start_frame),
      source_offset_frame(p_source_offset_frame),
      duration_frames(p_duration_frames) {}

AudioClip::~AudioClip() {}

ma_uint64 AudioClip::read_frames(void *buffer, ma_uint64 frame_count) {
    if (!is_loaded() || finished) return 0;
    const ma_uint64 remaining_frames = duration_frames == std::numeric_limits<ma_uint64>::max()
        ? std::numeric_limits<ma_uint64>::max()
        : duration_frames - position_frames;
    const ma_uint64 frames_to_read = std::min(frame_count, remaining_frames);
    if (frames_to_read == 0) {
        finished = true;
        return 0;
    }

    const ma_uint64 frames_read = decoder->read_frames(buffer, frames_to_read);
    position_frames += frames_read;
    if (frames_read < frames_to_read ||
        (duration_frames != std::numeric_limits<ma_uint64>::max() &&
            position_frames == duration_frames)) finished = true;
    return frames_read;
}

void AudioClip::mix_frames(
    float *output,
    float *scratch,
    ma_uint64 block_start_frame,
    ma_uint32 frame_count,
    ma_uint32 channels
) {
    if (finished) return;

    const ma_uint64 block_end_frame =
        frame_count > std::numeric_limits<ma_uint64>::max() - block_start_frame
        ? std::numeric_limits<ma_uint64>::max()
        : block_start_frame + frame_count;
    if (block_end_frame <= timeline_start_frame) return;

    const ma_uint64 overlap_start_frame = std::max(block_start_frame, timeline_start_frame);
    const ma_uint64 source_frame = overlap_start_frame - timeline_start_frame;
    if (duration_frames != std::numeric_limits<ma_uint64>::max() &&
        source_frame >= duration_frames) {
        return;
    }

    if (position_frames != source_frame &&
        !seek_to_timeline_frame(overlap_start_frame)) {
        return;
    }

    ma_uint64 frames_to_read = block_end_frame - overlap_start_frame;
    if (duration_frames != std::numeric_limits<ma_uint64>::max()) {
        frames_to_read = std::min(frames_to_read, duration_frames - source_frame);
    }
    if (frames_to_read == 0) return;

    const ma_uint64 frames_read = read_frames(scratch, frames_to_read);
    const std::size_t output_offset =
        static_cast<std::size_t>(overlap_start_frame - block_start_frame) * channels;
    for (std::size_t sample = 0;
        sample < static_cast<std::size_t>(frames_read) * channels;
        ++sample) {
        output[output_offset + sample] += scratch[sample];
    }
}

bool AudioClip::seek_to_timeline_frame(ma_uint64 timeline_frame) {
    if (!is_loaded()) return false;

    const ma_uint64 frame_index = timeline_frame > timeline_start_frame
        ? timeline_frame - timeline_start_frame
        : 0;
    if (duration_frames != std::numeric_limits<ma_uint64>::max() &&
        frame_index >= duration_frames) {
        position_frames = duration_frames;
        finished = true;
        return true;
    }

    if (frame_index > std::numeric_limits<ma_uint64>::max() - source_offset_frame) return false;
    if (!decoder->seek_to_frame(source_offset_frame + frame_index)) return false;
    position_frames = frame_index;
    finished = false;
    return true;
}

bool AudioClip::is_loaded() const {return decoder != nullptr && decoder->is_loaded(); }

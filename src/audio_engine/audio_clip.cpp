#include "audio_clip.h"
#include <utility>

AudioClip::AudioClip(std::unique_ptr<AudioDecoder> p_decoder, ma_uint64 p_timeline_start_frame)
    : decoder(std::move(p_decoder)), timeline_start_frame(p_timeline_start_frame) {}

AudioClip::~AudioClip() {}

ma_uint64 AudioClip::read_frames(void *buffer, ma_uint64 frame_count) {
    if (!is_loaded()) return 0;
    return decoder->read_frames(buffer, frame_count);
}

bool AudioClip::seek_to_frame(ma_uint64 frame_index) { return is_loaded() && decoder->seek_to_frame(frame_index); }

bool AudioClip::is_loaded() const {return decoder != nullptr && decoder->is_loaded(); }

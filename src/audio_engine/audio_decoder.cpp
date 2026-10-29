#include "audio_decoder.h"

AudioDecoder::AudioDecoder() = default;
AudioDecoder::~AudioDecoder() { close(); }

bool AudioDecoder::load(
    const std::string &fp,
    ma_uint32 target_sample_rate,
    ma_uint32 target_channels
) {
    ma_decoder_config d_config = ma_decoder_config_init(ma_format_f32, target_channels, target_sample_rate);
    ma_result result = ma_decoder_init_file(fp.c_str(), &d_config, &decoder);

    if (result != MA_SUCCESS) return false;
    
    loaded = true;
    return true;
}

void AudioDecoder::close() {
    if (!loaded) return;
    ma_decoder_uninit(&decoder);
    loaded = false;
}

ma_uint64 AudioDecoder::read_frames(void *p_buffer, ma_uint64 frame_count) {
    if (!loaded) return 0;

    ma_uint64 frames_read = 0;
    ma_decoder_read_pcm_frames(&decoder, p_buffer, frame_count, &frames_read);
    return frames_read;
}

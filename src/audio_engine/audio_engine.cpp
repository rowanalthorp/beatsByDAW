#include "audio_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cmath>
#include <limits>

using namespace godot;

void AudioEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_audio", "path"), &AudioEngine::start_audio);
    ClassDB::bind_method(D_METHOD("stop_audio"), &AudioEngine::stop_audio);
    ClassDB::bind_method(D_METHOD("is_audio_finished"), &AudioEngine::is_audio_finished);
    ClassDB::bind_method(D_METHOD("pause_audio"), &AudioEngine::pause_audio);
    ClassDB::bind_method(D_METHOD("resume_audio"), &AudioEngine::resume_audio);
    ClassDB::bind_method(D_METHOD("seek_audio", "timeline_seconds"), &AudioEngine::seek_audio);
    ClassDB::bind_method(D_METHOD("get_playback_time_seconds"), &AudioEngine::get_playback_time_seconds);
    ClassDB::bind_method(D_METHOD("add_track"), &AudioEngine::add_track);
    ClassDB::bind_method(D_METHOD("add_audio_source", "path"), &AudioEngine::add_audio_source);
    ClassDB::bind_method(
        D_METHOD("add_audio_clip", "path", "timeline_start_seconds", "source_offset_seconds", "duration_seconds"),
        &AudioEngine::add_audio_clip,
        DEFVAL(0.0),
        DEFVAL(-1.0)
    );
    ClassDB::bind_method(
        D_METHOD(
            "add_audio_clip_to_track",
            "track_id",
            "path",
            "timeline_start_seconds",
            "source_offset_seconds",
            "duration_seconds"
        ),
        &AudioEngine::add_audio_clip_to_track,
        DEFVAL(0.0),
        DEFVAL(-1.0)
    );
    ClassDB::bind_method(D_METHOD("set_track_volume", "track_id", "volume"), &AudioEngine::set_track_volume);
    ClassDB::bind_method(D_METHOD("start_audio_sources"), &AudioEngine::start_audio_sources);
}

AudioEngine::AudioEngine() {}

AudioEngine::~AudioEngine() {
    stop_audio();
}

int AudioEngine::start_audio(const String &path) {
    const int stop_result = stop_audio();
    if (stop_result != MA_SUCCESS) return stop_result;

    if (add_audio_source(path) < 0) return -1;
    return start_audio_sources();
}

int AudioEngine::stop_audio() {
    const ma_result result = audio_device.stop();
    audio_device.clear_tracks();
    tracks.clear();
    playback_started = false;
    return static_cast<int>(result);// godot does not jive with ma_result, so we cast to int
}

int AudioEngine::pause_audio() {
    const ma_result result = audio_device.pause();
    return static_cast<int>(result);// godot does not jive with ma_result, so we cast to int
}

int AudioEngine::resume_audio() {
    const ma_result result = audio_device.resume();
    return static_cast<int>(result);// godot does not jive with ma_result, so we cast to int
}

bool AudioEngine::is_audio_finished() const {
    return audio_device.is_finished();
}

bool AudioEngine::seek_audio(double timeline_seconds) {
    const bool has_clips = std::any_of(
        tracks.begin(),
        tracks.end(),
        [](const std::unique_ptr<TrackChannel> &track) {
            return track != nullptr && track->has_clips();
        }
    );
    if (!has_clips || !std::isfinite(timeline_seconds) || timeline_seconds < 0.0) return false;

    const long double frame = std::round(
        static_cast<long double>(timeline_seconds) * AudioDevice::sample_rate
    );
    if (frame >= static_cast<long double>(std::numeric_limits<ma_uint64>::max())) return false;

    return audio_device.seek_to_frame(static_cast<ma_uint64>(frame));
}

double AudioEngine::get_playback_time_seconds() const {
    return static_cast<double>(audio_device.get_playback_position_frames()) / AudioDevice::sample_rate;
}

int AudioEngine::add_audio_source(const String &path) { return add_audio_clip(path, 0.0); }

int AudioEngine::add_track() {
    if (playback_started || next_track_id == std::numeric_limits<int>::max()) return -1;

    const int track_id = next_track_id++;
    auto track = std::make_unique<TrackChannel>(track_id);
    tracks.push_back(std::move(track));
    audio_device.add_track(tracks.back().get());
    return track_id;
}

TrackChannel *AudioEngine::find_track(int track_id) const {
    for (const std::unique_ptr<TrackChannel> &track : tracks) {
        if (track != nullptr && track->get_id() == track_id) {
            return track.get();
        }
    }
    return nullptr;
}

std::unique_ptr<AudioClip> AudioEngine::create_audio_clip(
    const String &path,
    double timeline_start_seconds,
    double source_offset_seconds,
    double duration_seconds
) {
    if (!std::isfinite(timeline_start_seconds) || timeline_start_seconds < 0.0 ||
        !std::isfinite(source_offset_seconds) || source_offset_seconds < 0.0 ||
        !std::isfinite(duration_seconds) || (duration_seconds != -1.0 && duration_seconds <= 0.0)) return nullptr;

    const long double start_frame = std::round(
        static_cast<long double>(timeline_start_seconds) * AudioDevice::sample_rate
    );
    const long double source_offset_frame = std::round(
        static_cast<long double>(source_offset_seconds) * AudioDevice::sample_rate
    );
    const bool play_to_end_of_source = duration_seconds == -1.0;
    const long double duration_frame = play_to_end_of_source
        ? 0.0L
        : std::round(static_cast<long double>(duration_seconds) * AudioDevice::sample_rate);
    if (start_frame >= static_cast<long double>(std::numeric_limits<ma_uint64>::max()) ||
        source_offset_frame >= static_cast<long double>(std::numeric_limits<ma_uint64>::max()) ||
        (!play_to_end_of_source &&
            (duration_frame <= 0.0L ||
                duration_frame >= static_cast<long double>(std::numeric_limits<ma_uint64>::max())))) {
        return nullptr;
    }
    std::string std_path = path.utf8().get_data(); // converting godot string to a standard string
    auto decoder = std::make_unique<AudioDecoder>();

    if (!decoder->load(std_path, AudioDevice::sample_rate, AudioDevice::output_channels)) return nullptr;
    if (source_offset_frame > 0.0L &&
        !decoder->seek_to_frame(static_cast<ma_uint64>(source_offset_frame))) return nullptr;

    return std::make_unique<AudioClip>(
        std::move(decoder),
        static_cast<ma_uint64>(start_frame),
        static_cast<ma_uint64>(source_offset_frame),
        play_to_end_of_source
            ? std::numeric_limits<ma_uint64>::max()
            : static_cast<ma_uint64>(duration_frame)
    );
}

int AudioEngine::add_audio_clip(
    const String &path,
    double timeline_start_seconds,
    double source_offset_seconds,
    double duration_seconds
) {
    if (playback_started) return -1;

    std::unique_ptr<AudioClip> clip = create_audio_clip(
        path,
        timeline_start_seconds,
        source_offset_seconds,
        duration_seconds
    );
    if (clip == nullptr) return -1;

    const int track_id = add_track();
    if (track_id < 0) return -1;
    find_track(track_id)->add_clip(std::move(clip));
    return track_id;
}

bool AudioEngine::add_audio_clip_to_track(
    int track_id,
    const String &path,
    double timeline_start_seconds,
    double source_offset_seconds,
    double duration_seconds
) {
    if (playback_started) return false;

    TrackChannel *track = find_track(track_id);
    if (track == nullptr) return false;

    std::unique_ptr<AudioClip> clip = create_audio_clip(
        path,
        timeline_start_seconds,
        source_offset_seconds,
        duration_seconds
    );
    if (clip == nullptr) return false;

    track->add_clip(std::move(clip));
    return true;
}

bool AudioEngine::set_track_volume(int track_id, float volume) {
    if (playback_started) return false;
    return audio_device.set_track_volume(track_id, volume);
}

int AudioEngine::start_audio_sources() {
    const bool has_clips = std::any_of(
        tracks.begin(),
        tracks.end(),
        [](const std::unique_ptr<TrackChannel> &track) {
            return track != nullptr && track->has_clips();
        }
    );
    if (playback_started || !has_clips) return -1;

    const ma_result result = audio_device.start();
    if (result != MA_SUCCESS) { stop_audio(); } 
    else { playback_started = true; }
    return static_cast<int>(result);
}
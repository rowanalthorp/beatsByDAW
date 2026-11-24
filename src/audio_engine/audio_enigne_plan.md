# NOTE: AI suggests implementing so far this code structure, which honestly I am a big fan of 

src/
├── register_types.cpp
└── audio_engine/
    ├── audio_engine.h/.cpp       # Godot-facing API and lifecycle
    ├── mixer_core.h/.cpp         # Mixes tracks into the output buffer
    ├── track_channel.h/.cpp      # Per-track state: clips, volume, pan, mute, solo
    ├── audio_clip.h/.cpp         # Decoded audio source and timeline start frame
    ├── audio_decoder.h/.cpp      # Loads files and converts them to float samples
    └── audio_device.h/.cpp       # Opens the output device and calls the mixer

Tracks may contain multiple clips. `add_audio_source(path)` and the existing
`add_audio_clip(path, ...)` create a new track; `add_track()` creates an empty
track and `add_audio_clip_to_track(track_id, path, ...)` adds a clip to it.
Seeking before `start_audio_sources()` sets the timeline frame used by
playback, and `get_playback_time_seconds()` reports the audio callback's
rendered timeline position.


Methods in AudioEngine
```cpp
int AudioEngine::start_audio(const String &path)
- param 1: takes in the path for the wav

int AudioEngine::stop_audio()

int AudioEngine::pause_audio()

int AudioEngine::resume_audio()

bool AudioEngine::is_audio_finished()

int AudioEngine::add_audio_source(const String &path)
- param 1: takes in the path for the wav

int AudioEngine::add_track()

bool AudioEngine::add_audio_clip_to_track(
    int track_id,
    const String &path,
    double timeline_start_seconds,
    double source_offset_seconds = 0.0,
    double duration_seconds = -1.0
)
- adds a clip to an existing track and returns whether it succeeded

int AudioEngine::add_audio_clip(
    const String &path,
    double timeline_start_seconds,
    double source_offset_seconds = 0.0,
    double duration_seconds = -1.0
)
- param 1: takes in the path for the wav
- param 2: second you want to add the audio clip at in the playing
- param 3: offset into the source file; defaults to its beginning
- param 4: clip duration; -1 plays from the offset through end of file

bool AudioEngine::set_track_volume(int track_id, float volume)
- param 1: which source's id you want this to apply to
- param 2: what volume you wuold like to change to

int AudioEngine::start_audio_sources()
```
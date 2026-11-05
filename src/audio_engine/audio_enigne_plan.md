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
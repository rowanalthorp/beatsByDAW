## Objectives

### Objective 1: Timeline and editing interface
* Objective (implement the multi-track timeline UI and clip editing workflow in Godot)
  * PI1 (basic): multi-track timeline with transport controls (play/pause/stop, playhead, seek), add/delete tracks
  * PI2 (basic): clip operations on the timeline: move, cut, trim, split, delete, with grid snapping
  * PI3 (expected): copy/paste, duplicate, loop regions, undo/redo
  * PI4 (expected): project save/load (tracks, clips, settings) with round-trip verification
  * PI5 (advanced): waveform rendering with zoom/scroll; measure UI frame time as track and clip count scale

### Objective 2: Audio engine and mixing (C++ GDExtension)
* Objective (implement the C++ audio backend for playback, mixing, recording, and export)
  * PI1 (basic): GDExtension backend that imports/decodes audio files and mixes multiple tracks to output
  * PI2 (basic): per-track volume, pan, mute/solo, and a master bus
  * PI3 (expected): fade in/out and reverse; offline render/export of the mix to WAV
  * PI4 (expected): record audio from an input device into a new track
  * PI5 (advanced): benchmark latency and CPU load vs. track count and buffer size; compare against Godot's built-in AudioServer mixing

### Objective 3: Virtual instruments and note editor
* Objective (implement playable virtual instruments driven by an editable note sequence)
  * PI1 (basic): piano-roll editor: place, move, resize, delete notes
  * PI2 (basic): piano instrument (sample-based or synthesized) playing piano-roll notes
  * PI3 (expected): guitar via Karplus-Strong plucked-string synthesis; drum kit with a step sequencer
  * PI4 (expected): tuning controls: transposition, reference pitch (A4), key/scale
  * PI5 (advanced): MIDI file import/export, with quantization of imported notes to the project grid

### Objective 4: Audio effects
* Objective (implement a per-track effects chain)
  * PI1 (basic): biquad filters: low/high-pass and parametric EQ
  * PI2 (basic): delay/echo with feedback and wet/dry mix
  * PI3 (expected): algorithmic reverb (Schroeder/Freeverb-style)
  * PI4 (expected): per-track insert chain UI with reorderable effects and parameter controls
  * PI5 (advanced): spectral-subtraction noise reduction; measure SNR improvement on clean clips with added noise

### Objective 5: Audio analysis on import (MIR)
* Objective (implement and evaluate tempo, beat, and pitch analysis of imported audio)
  * PI1 (basic): onset detection (spectral flux) on imported clips
  * PI2 (basic): tempo estimation; set project BPM/grid from the estimate
  * PI3 (expected): beat tracking evaluated on annotated datasets (e.g., Ballroom, GTZAN) using mir_eval F-measure; compare against librosa
  * PI4 (expected): monophonic pitch detection (YIN/pYIN) evaluated on an annotated dataset (e.g., MIR-1K, MDB-stem-synth) using raw pitch accuracy
  * PI5 (advanced): pitch correction (autotune): snap detected f0 to a selected key/scale and resynthesize with PSOLA; measure pitch error before/after

### Objective 6: Time-stretching and pitch-shifting (MIR)
* Objective (implement and evaluate time-scale and pitch modification of audio clips)
  * PI1 (basic): phase-vocoder time-stretch at arbitrary ratios
  * PI2 (basic): pitch shift in semitones via time-stretch + resampling
  * PI3 (expected): phase-locked vocoder to reduce phasiness; compare against the basic vocoder
  * PI4 (expected): WSOLA implementation; compare quality and runtime per minute of audio against the vocoder and Rubber Band
  * PI5 (advanced): transient preservation by splitting harmonic/percussive components (HPSS) and stretching each with the appropriate method

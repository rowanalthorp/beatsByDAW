# beatsByDAW

beatsByDAW aims to provide a simple, flexible environment where musicians can create, edit, and mix their own tunes. <br><br>
In the application we will offer:
* Virtual Instruments, able to tune and all that jazz
  * Piano
  * Guitar
  * Drums
* Audio manipulation: 
  * Cut, trim, split, and rearrange audio clips
  * Adjust volume and panning
  * Fade audio in and out
  * Change pitch
  * Reverb (and all that other stuff)
  * Change temp / time-stretch audio
  * Loop and duplicate sections
  * Reverse audio
  * Noise reduction/filter
  * Apply basic effects such as EQ, reverb, and delay
* An environment where the user can add and delete and etc, manipulate the notes they are virtually “playing”
* Import Audio (beat/tempo detection and pitch detection)
* Record Audio
* Ability to copy and paste audio
* Autotune / pitch-correction
* Mixing
* Multi Tracks on timeline
* Save, load, and export,
<br>
(NOTE: probably some stuff will have to cut for scope)
<br><br>

beatsByDAW will provide the core tools and the other jazzy stuff one would want when putting together their own tunes. The plan is to build the application in Godot, primarily because we are more experienced in it and it handles the more tedious aspects such as UI, allowing us to focus more on the audio and music parts. The backend would be using the C++ GDE extension for better performance.

## Tools
* Godot 4 (UI, timeline, editors)
* godot-cpp (https://github.com/godotengine/godot-cpp): C++ bindings for the GDExtension backend (audio engine, DSP, analysis)
* Python with librosa (https://librosa.org) and mir_eval [16]: offline evaluation of the analysis and time-stretch objectives
* FMP notebooks [17]: Python reference implementations used as baselines while writing the C++ versions

## Datasets
* Ballroom [14]: tempo and beat annotations, used to evaluate tempo estimation and beat tracking (Obj. 5)
* MDB-stem-synth [15]: solo stems with exact f0 annotations, used to evaluate pitch detection and pitch correction (Obj. 5)

## Objectives


### Objective 1: Timeline and editing interface - Brett
* Objective (implement the multi-track timeline UI and clip editing workflow in Godot)
  * PI1 (basic): multi-track timeline with transport controls (play/pause/stop, playhead, seek), add/delete tracks
  * PI2 (basic): clip operations on the timeline: move, cut, trim, split, delete, with grid snapping
  * PI3 (expected): copy/paste, duplicate, loop regions, undo/redo
  * PI4 (expected): project save/load (tracks, clips, settings) with round-trip verification
  * PI5 (advanced): waveform rendering with zoom/scroll; measure UI frame time as track and clip count scale

### Objective 2: Audio engine and mixing (C++ GDExtension) - Rowan
* Objective (implement the C++ audio backend for playback, mixing, recording, and export)
  * PI1 (basic): GDExtension backend that imports/decodes audio files and mixes multiple tracks to output
  * PI2 (basic): per-track volume, pan, mute/solo, and a master bus
  * PI3 (expected): fade in/out and reverse; offline render/export of the mix to WAV
  * PI4 (expected): record audio from an input device into a new track
  * PI5 (advanced): benchmark latency and CPU load vs. track count and buffer size; compare against Godot's built-in AudioServer mixing

### Objective 3: Virtual instruments and note editor - Kris
* Objective (implement playable virtual instruments driven by an editable note sequence)
  * PI1 (basic): piano-roll editor: place, move, resize, delete notes
  * PI2 (basic): piano instrument (sample-based or synthesized) playing piano-roll notes
  * PI3 (expected): guitar via Karplus-Strong plucked-string synthesis; drum kit with a step sequencer
  * PI4 (expected): tuning controls: transposition, reference pitch (A4), key/scale
  * PI5 (advanced): MIDI file import/export, with quantization of imported notes to the project grid

### Objective 4: Audio effects - Rowan
* Objective (implement a per-track effects chain)
  * PI1 (basic): biquad filters: low/high-pass and parametric EQ
  * PI2 (basic): delay/echo with feedback and wet/dry mix
  * PI3 (expected): algorithmic reverb (Schroeder/Freeverb-style)
  * PI4 (expected): per-track insert chain UI with reorderable effects and parameter controls
  * PI5 (advanced): spectral-subtraction noise reduction; measure SNR improvement on clean clips with added noise

### Objective 5: Audio analysis on import (MIR) - Brett
* Objective (implement and evaluate tempo, beat, and pitch analysis of imported audio)
  * PI1 (basic): onset detection (spectral flux) on imported clips
  * PI2 (basic): tempo estimation; set project BPM/grid from the estimate
  * PI3 (expected): beat tracking evaluated on annotated datasets (e.g., Ballroom, GTZAN) using mir_eval F-measure; compare against librosa
  * PI4 (expected): monophonic pitch detection (YIN) evaluated on MDB-stem-synth using raw pitch accuracy; compare against librosa's pYIN
  * PI5 (advanced): pitch correction (autotune): snap detected f0 to a selected key/scale and resynthesize with PSOLA; measure pitch error before/after

### Objective 6: Time-stretching and pitch-shifting (MIR) - Kris
* Objective (implement and evaluate time-scale and pitch modification of audio clips)
  * PI1 (basic): phase-vocoder time-stretch at arbitrary ratios
  * PI2 (basic): pitch shift in semitones via time-stretch + resampling
  * PI3 (expected): phase-locked vocoder to reduce phasiness; compare against the basic vocoder
  * PI4 (expected): WSOLA implementation; compare quality and runtime per minute of audio against the vocoder and Rubber Band
  * PI5 (advanced): transient preservation by splitting harmonic/percussive components (HPSS) and stretching each with the appropriate method

## Timeline
* Week 1-2: Objecitves 1-3 (Basic, Expected, Advanced)
* Week 3-4: Objectives 4-6 (Basic, Expected)
* Week 5: Objectives 4-6 (Advanced)
* Week 6: Final Preperations

## Related Work

* Obj. 1: DAW interfaces are largely built on metaphors from analog hardware such as tape machines and mixing desks [1]; beatsByDAW keeps the familiar track/timeline layout but limits features so it stays approachable for beginners.
* Obj. 2: Mixing, panning, fades, and delay-based processing are standard digital audio effects [2], implemented here as separate processing units in the C++ backend.
* Obj. 3: Karplus-Strong synthesis produces plucked-string and drum sounds from a noise burst in a filtered delay line [3]; the guitar uses the ring-buffer structure from [4], and MIDI import/export follows the Standard MIDI File format [5].
* Obj. 4: EQ filters use the biquad coefficient formulas from [6], the reverb uses Schroeder's comb and all-pass design [7], and noise reduction subtracts an estimated noise spectrum from each frame [8].
* Obj. 5: Onsets are detected with spectral flux [9] and beats with dynamic programming [10], which needs no training data, unlike learned TCN trackers [11]. Pitch is detected with YIN [12] and corrected pitch is resynthesized with PSOLA [13]. Tempo and beat accuracy are measured on Ballroom [14] and pitch accuracy on MDB-stem-synth [15] using mir_eval [16], with the FMP notebook implementations [17] as baselines.
* Obj. 6: Time-stretching uses a phase-locked vocoder to reduce phasiness [18], WSOLA as a time-domain alternative [19], and harmonic/percussive separation to keep transients sharp [20].

Related software:
* Godot MIDI Player (https://bitbucket.org/arlez80/godot-midi-player/src/master/): MIDI file playback in Godot (Obj. 3).
* GDScriptAudioImport (https://github.com/Gianclgar/GDScriptAudioImport): runtime audio import in Godot (Obj. 2).
* MeloMIDI (https://github.com/4321ba/MeloMIDI): wave-to-MIDI editor built in Godot (Obj. 5).
* WaoN (https://github.com/kichiki/WaoN): wave-to-notes transcriber with a phase vocoder (Obj. 5, 6).
* ISSE (https://sourceforge.net/projects/isse/): spectrogram-based source separation editor (Obj. 4).

## References

[1] "Beyond Skeuomorphism: The Evolution of Music Production Software User Interface Metaphors," 2015 [Online]. Available: https://ethanhein.com/wp/2014/the-great-music-interface-metaphor-shift/

[2] "DAFX: Digital Audio Effects, 2nd ed.," 2011 [Online]. Available: https://dafx.de/DAFX_Book_Page_2nd_edition/matlab.html

[3] "Digital Synthesis of Plucked-String and Drum Timbres," 1983 [Online]. Available: https://doi.org/10.2307/3680062

[4] "COS 126 Programming Assignment: Plucking a Guitar String," 2007 [Online]. Available: https://www.cs.princeton.edu/courses/archive/fall07/cos126/assignments/guitar.html

[5] "Standard MIDI Files Specification," [Online]. Available: https://midi.org/?p=1452

[6] "Audio EQ Cookbook," 2021 [Online]. Available: https://www.w3.org/TR/audio-eq-cookbook/

[7] "Natural Sounding Artificial Reverberation," 1962 [Online]. Available: https://aes2.org/publications/elibrary-page/?id=849

[8] "Suppression of Acoustic Noise in Speech Using Spectral Subtraction," 1979 [Online]. Available: https://doi.org/10.1109/TASSP.1979.1163209

[9] "A Tutorial on Onset Detection in Music Signals," 2005 [Online]. Available: https://doi.org/10.1109/TSA.2005.851998

[10] "Beat Tracking by Dynamic Programming," 2007 [Online]. Available: https://www.ee.columbia.edu/~dpwe/pubs/Ellis07-beattrack.pdf

[11] "Temporal Convolutional Networks for Musical Audio Beat Tracking," 2019 [Online]. Available: https://ieeexplore.ieee.org/document/8902578

[12] "YIN, a Fundamental Frequency Estimator for Speech and Music," 2002 [Online]. Available: https://doi.org/10.1121/1.1458024

[13] "Pitch-Synchronous Waveform Processing Techniques for Text-to-Speech Synthesis Using Diphones," 1990 [Online]. Available: https://courses.grainger.illinois.edu/ece420/5_PSOLA.pdf

[14] "An Experimental Comparison of Audio Tempo Induction Algorithms," 2006 [Online]. Available: https://doi.org/10.1109/TSA.2005.858509

[15] "An Analysis/Synthesis Framework for Automatic F0 Annotation of Multitrack Datasets," 2017 [Online]. Available: https://archives.ismir.net/ismir2017/paper/000164.pdf

[16] "mir_eval: A Transparent Implementation of Common MIR Metrics," 2014 [Online]. Available: https://archives.ismir.net/ismir2014/paper/000320.pdf

[17] "FMP Notebooks: Python Notebooks for Fundamentals of Music Processing," [Online]. Available: https://www.audiolabs-erlangen.de/resources/MIR/FMP/C0/C0.html

[18] "Improved Phase Vocoder Time-Scale Modification of Audio," 1999 [Online]. Available: https://doi.org/10.1109/89.759041

[19] "Waveform Similarity Based Overlap-Add (WSOLA) for Time-Scale Modification of Speech: Structures and Evaluation," 1993 [Online]. Available: https://www.isca-archive.org/eurospeech_1993/roelands93_eurospeech.html

[20] "Improving Time-Scale Modification of Music Signals Using Harmonic-Percussive Separation," 2014 [Online]. Available: https://doi.org/10.1109/LSP.2013.2294023

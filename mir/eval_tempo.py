# obj 5 PI1/PI2 evaluation: run onsets + tempo over a bunch of ballroom tracks and score them
# this is mainly meant to be a test to make sure everything is right, and showcase my accuracy (well, if it IS accurate.........)
# note to self -> run from the repo root with the venv active:
#   .\mir\.venv\Scripts\Activate.ps1
#   python mir/eval_tempo.py (5 tracks per dance style = 50 tracks)
#   python mir/eval_tempo.py 1000 (every track, takes a while)
#
# for each track: our tempo (tempo.py) vs librosa's vs the true BPM, plus how well our onsets (onsets.py) agree w/
# librosa's. tempo gets scored w/ the two standard tempo metrics from rhythm slide 16.
# everything gets saved to mir/out/eval_tempo.csv for the report.

import csv
import glob
import os
import sys

import librosa
import mir_eval
import numpy as np

# reusing the functions from onsets.py and tempo.py so this tests the exact same code, not a copy of it (also cuz its easier lol)
from onsets import detect_onsets, onset_strength
from tempo import beat_histogram, bpms, enhance_harmonics, true_tempo

srate = 44100
win_size = 1024
hop_size = 128


def accuracy1(estimate, truth, tolerance=0.04):
    # within 4% of the true BPM counts as right (slide 16), since labels are hand-tapped and never exact
    return abs(estimate - truth) <= tolerance * truth


def accuracy2(estimate, truth, tolerance=0.04):
    # also counts 1/3, 1/2, 2 or 3x the true BPM (slide 16) since rhythm repeats at several levels (subdivision, beat, bar)
    # that are 2x or 3x apart (slide 5), so being off by exactly those factors means we found a real level, just not the labelled one.
    # acc2 - acc1 = how many of those we make, which the paper's octave rule (not added yet) is supposed to fix
    return any(accuracy1(estimate, truth * factor, tolerance) for factor in (1 / 3, 1 / 2, 1, 2, 3))


def pick_tracks(per_style):
    # same first few tracks of every dance style each run, so results are repeatable and every style gets tested
    tracks = []
    for style in sorted(glob.glob("mir/data/BallroomData/*/")):
        wavs = sorted(glob.glob(os.path.join(style, "*.wav")))
        # skip anything w/o a tempo label since there's nothing to score it against
        labelled = [w for w in wavs if true_tempo(os.path.splitext(os.path.basename(w))[0])]
        tracks += labelled[:per_style]
    return tracks


def main(per_style):
    tracks = pick_tracks(per_style)
    curve_rate = srate / hop_size
    rows = []

    for i, path in enumerate(tracks, 1):
        name = os.path.splitext(os.path.basename(path))[0]
        style = os.path.basename(os.path.dirname(path))
        audio, _ = librosa.load(path, sr=srate, mono=True)

        # compute the onset curve once and use it for both tempo and onsets so each track only gets analyzed once
        onset_curve = onset_strength(audio, srate, win_size, hop_size)
        our_bpm = bpms[np.argmax(enhance_harmonics(beat_histogram(onset_curve, curve_rate)))]
        librosa_bpm = float(librosa.feature.tempo(y=audio, sr=srate)[0])
        truth = true_tempo(name)

        # no onset labels in ballroom, so this is agreement w/ librosa (same check as onsets.py), not accuracy
        our_onsets = detect_onsets(onset_curve, srate, hop_size)
        librosa_onsets = librosa.onset.onset_detect(y=audio, sr=srate, units="time")
        onset_f = mir_eval.onset.f_measure(librosa_onsets, our_onsets, window=0.05)[0]

        rows.append({
            "style": style, "track": name, "true_bpm": truth,
            "our_bpm": our_bpm, "librosa_bpm": round(librosa_bpm, 2),
            "our_acc1": accuracy1(our_bpm, truth), "our_acc2": accuracy2(our_bpm, truth),
            "librosa_acc1": accuracy1(librosa_bpm, truth), "librosa_acc2": accuracy2(librosa_bpm, truth),
            "onset_agreement_f": round(onset_f, 3),
        })
        # print as it goes since the full dataset takes a while and it's nice to see it's not stuck
        print(f"[{i}/{len(tracks)}] {style}/{name}: true {truth:.1f}, ours {our_bpm:.1f}, librosa {librosa_bpm:.1f}, onset F {onset_f:.2f}")

    # csv so the per-track results can go straight into a table for the report or get opened in excel
    os.makedirs("mir/out", exist_ok=True)
    with open("mir/out/eval_tempo.csv", "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    def percent(key):
        # true/false averages to the fraction of tracks that got it right
        return 100 * np.mean([row[key] for row in rows])

    print(f"\n{len(rows)} tracks")
    print(f"accuracy 1:  ours {percent('our_acc1'):.1f}%   librosa {percent('librosa_acc1'):.1f}%")
    print(f"accuracy 2:  ours {percent('our_acc2'):.1f}%   librosa {percent('librosa_acc2'):.1f}%")
    print(f"onset agreement w/ librosa (mean F): {np.mean([row['onset_agreement_f'] for row in rows]):.2f}")
    print("saved to mir/out/eval_tempo.csv")

if __name__ == "__main__":
        main(int(sys.argv[1]) if len(sys.argv) > 1 else 5)
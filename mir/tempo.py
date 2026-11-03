# obj 5 PI2: tempo estimate from the onset curve
# note to self -> run from the repo root with the venv active:
#   .\mir\.venv\Scripts\Activate.ps1
#   python mir/tempo.py mir/data/BallroomData/ChaChaCha/Albums-Fire-08.wav
#
# chops the onset curve into ~6 s windows and, in each one, checks which time gaps between spikes
# repeat the most (autocorrelation = compare the curve w/ a shifted copy of itself). those gaps get
# turned into BPM and added up over all windows into a "beat histogram", then tempos whose half-tempo
# is also strong get a boost. the tallest peak is the first guess.
#
# then each window tests its top 8 tempo guesses by sliding an ideal beat (pulse train) over the onset curve,
# and the best-fitting guess gets a vote. the paper's octave rule compares the first guess w/ the top 2 votes
# to catch "right beat, wrong octave" mistakes (e.g. 200 instead of 100).
#
# steps + numbers from the rhythm slides (slides 13-14) and section 2 of the same paper I used in onsets.py:
# https://webhome.csc.uvic.ca/~gtzan/output/icassp2013tempo_gtzan.pdf
# this file is just a lot of converting the paper's equations to code ngl

import glob
import os
import sys

import librosa
import matplotlib.pyplot as plt
import numpy as np

from onsets import onset_strength # I spent so much time on that, by god am I re-using it

srate = 44100
win_size = 1024
hop_size = 128

# windows over the onset curve, from the paper: 2048 values (~6 s) w/ a hop of 128 (~0.37 s)
curve_win = 2048
curve_hop = 128

# histogram goes down to 25 instead of the paper's 50 so BH(0.5 * b) below exists for b = 50-100
bpm_min, bpm_max, bpm_step = 25.0, 200.0, 0.25
bpms = np.arange(bpm_min, bpm_max + bpm_step, bpm_step)


def generalized_autocorrelation(window, exponent=0.5):
    # magnitude^0.5 instead of the normal ^2 since the paper found it gives sharper peaks w/o getting too noisy (zero-padded to double length like the paper)
    spectrum = np.fft.rfft(window, n=2 * len(window))
    return np.fft.irfft(np.abs(spectrum) ** exponent)[:len(window)] # side note, these imported functions names suck and read like gibberish "np.fft.irfft" bruh. Only makes sense w/ context


def lags_to_histogram(autocorr, curve_rate):
    # each lag t (in curve values) is a BPM, 60 * curve_rate / t, snapped to 0.25 BPM bins like the paper
    lags = np.arange(1, len(autocorr))
    lag_bpms = 60.0 * curve_rate / lags
    keep = (lag_bpms >= bpm_min) & (lag_bpms <= bpm_max)
    bins = np.round((lag_bpms[keep] - bpm_min) / bpm_step).astype(int)

    # average lags that land in the same bin and fill empty bins from their neighbours, both from the paper
    sums = np.bincount(bins, weights=autocorr[lags[keep]], minlength=len(bpms))
    counts = np.bincount(bins, minlength=len(bpms))
    filled = counts > 0
    return np.interp(bpms, bpms[filled], sums[filled] / counts[filled])


def beat_histogram(onset_curve, curve_rate):
    histogram = np.zeros(len(bpms))
    for start in range(0, len(onset_curve) - curve_win + 1, curve_hop):
        window = onset_curve[start:start + curve_win]
        histogram += lags_to_histogram(generalized_autocorrelation(window), curve_rate)
    return histogram


def enhance_harmonics(histogram):
    # EBH(b) = BH(b) + BH(0.5 * b) from the paper so a tempo gets boosted when its half-tempo is also strong, then cut back to 50-200
    enhanced = histogram + np.interp(0.5 * bpms, bpms, histogram)
    enhanced[bpms < 50] = 0
    return enhanced


def find_peaks(histogram, low=50, high=180, count=8, spread=1.5):
    # a bin only counts as a peak if it beats every bin within +-1.5 BPM, so one wide bump doesn't eat all 8 spots (top 8 between 50-180 from the paper)
    reach = int(spread / bpm_step)
    peaks = []
    for i in range(len(histogram)):
        if not (low <= bpms[i] <= high) or histogram[i] <= 0:
            continue
        neighbours = np.concatenate([histogram[max(0, i - reach):i], histogram[i + 1:i + reach + 1]])
        if histogram[i] > neighbours.max():
            peaks.append(i)
    # tallest first, so peaks[0] is the strongest one
    peaks.sort(key=lambda i: histogram[i], reverse=True)
    return bpms[peaks[:count]]


def pulse_train_scores(window, period):
    # the paper's ideal beat: 4 full pulses one period apart, plus 4 half-weight pulses 2 periods apart and 4 more 1.5 periods apart,
    # since those "capture the common integer relations based on meter" (paper sec 2.3). paper doesn't say how many of those extra pulses,
    # so this uses 4 of each like essentia's version: https://github.com/MTG/essentia/blob/master/src/algorithms/rhythm/percivalevaluatepulsetrains.cpp
    match = np.zeros(period)
    # try every phase (start offset) within one period since we don't know where the beat starts
    for phase in range(period):
        for k in range(4):
            for spacing, weight in ((period, 1.0), (2 * period, 0.5), (1.5 * period, 0.5)):
                index = int(phase + k * spacing)
                # essentia doesn't check the end of the window (reads past it), the paper doesn't say either, so pulses past the end just count as 0
                if index < len(window):
                    match[phase] += weight * window[index]

    # max = how well the best phase lines up, variance = how much better that phase is than the rest (a steady beat lines up at one phase only)
    return match.max(), match.var()


def pulse_histogram(onset_curve, curve_rate):
    # in each window the 8 tempo candidates race their pulse trains against the onset curve and the winner gets a vote,
    # so the final pick comes from "which beat grid actually lines up w/ the hits" instead of only the autocorrelation
    histogram = np.zeros(len(bpms))
    running_beats = np.zeros(len(bpms))
    for start in range(0, len(onset_curve) - curve_win + 1, curve_hop):
        window = onset_curve[start:start + curve_win]
        # candidates come from the beat histogram summed over every window so far (the "cumulative BH" in the paper's fig 1),
        # so they settle down as more of the song gets heard instead of jumping around w/ each 6 s window
        running_beats += lags_to_histogram(generalized_autocorrelation(window), curve_rate)
        candidates = find_peaks(enhance_harmonics(running_beats))
        if len(candidates) == 0:
            continue

        max_scores = np.zeros(len(candidates))
        var_scores = np.zeros(len(candidates))
        for i, bpm in enumerate(candidates):
            # BPM back to a period in onset curve values, same conversion as the lags just flipped around
            period = int(round(60.0 * curve_rate / bpm))
            max_scores[i], var_scores[i] = pulse_train_scores(window, period)
        # silent window, nothing to vote on (and would divide by 0 below)
        if max_scores.sum() == 0 or var_scores.sum() == 0:
            continue

        # max and variance are on totally different scales, so each gets normalized to sum to 1 before adding, then normalized again (all from the paper)
        combined = max_scores / max_scores.sum() + var_scores / var_scores.sum()
        combined = combined / combined.sum()
        best = np.argmax(combined)
        # winner's score goes into its 0.25 BPM bin, same bin math as lags_to_histogram
        histogram[int(round((candidates[best] - bpm_min) / bpm_step))] += combined[best]
    return histogram


def octave_rule(enhanced, pulses, tolerance=0.04, threshold=68):
    # the paper's octave fix: compare the beat histogram's top pick w/ the pulse histogram's top 2, and if two of them
    # are exactly 2x apart (within 4%) we know it's an octave mixup, so pick between them w/ the 68 BPM cutoff
    beat_pick = bpms[np.argmax(enhanced)]
    pulse_picks = find_peaks(pulses, low=bpm_min, high=bpm_max, count=2)
    if len(pulse_picks) == 0:
        return beat_pick

    picks = [beat_pick] + list(pulse_picks)
    for i in range(len(picks)):
        for j in range(i + 1, len(picks)):
            lower, higher = sorted((picks[i], picks[j]))
            if abs(higher / (2 * lower) - 1) <= tolerance:
                # at or below 68 the lower one is probably half the real beat so double it, otherwise keep it
                return 2 * lower if lower <= threshold else lower
    # no octave mixup found, trust the pulse trains
    return pulse_picks[0]


def true_tempo(name):
    # ballroom tempo labels (data2.tar.gz), first number in the file is the BPM
    matches = glob.glob(f"mir/data/BallroomAnnotations/ballroomGroundTruth/{name}.*")
    if not matches:
        return None
    with open(matches[0]) as f:
        return float(f.read().replace(",", " ").split()[0])


def main(path):
    audio, _ = librosa.load(path, sr=srate, mono=True)
    curve_rate = srate / hop_size
    onset_curve = onset_strength(audio, srate, win_size, hop_size)

    enhanced = enhance_harmonics(beat_histogram(onset_curve, curve_rate))
    pulses = pulse_histogram(onset_curve, curve_rate)
    # keep the first guess around too so we can see what the pulse trains + octave rule changed
    first_guess = bpms[np.argmax(enhanced)]
    our_bpm = octave_rule(enhanced, pulses)
    # librosa's tempo as the baseline https://librosa.org/doc/latest/api/generated/librosa.feature.tempo.html
    librosa_bpm = float(librosa.feature.tempo(y=audio, sr=srate)[0])

    name = os.path.splitext(os.path.basename(path))[0]
    truth = true_tempo(name)
    truth_text = f"{truth:.1f}" if truth else "?"
    print(f"{name}: ours {our_bpm:.1f} BPM (first guess {first_guess:.1f}), librosa {librosa_bpm:.1f} BPM, true {truth_text} BPM")

    # top = the autocorrelation histogram the first guess comes from, bottom = the pulse train votes, same BPM axis so peaks line up
    fig, (top, bottom) = plt.subplots(2, 1, figsize=(12, 6), sharex=True)
    top.plot(bpms, enhanced, color="black", linewidth=0.8)
    top.set(title=f"{name}: enhanced beat histogram", ylabel="strength")
    bottom.bar(bpms, pulses, width=bpm_step * 4, color="gray")
    bottom.set(title="pulse train votes", xlabel="BPM", ylabel="votes", xlim=(50, 200))
    for ax in (top, bottom):
        ax.axvline(our_bpm, color="tab:red", label=f"ours {our_bpm:.1f}")
        ax.axvline(librosa_bpm, color="tab:blue", linestyle="--", label=f"librosa {librosa_bpm:.1f}")
        if truth:
            ax.axvline(truth, color="tab:green", linestyle=":", label=f"true {truth:.1f}")
    top.legend(loc="upper right")
    fig.tight_layout()

    os.makedirs("mir/out", exist_ok=True)
    out_path = f"mir/out/tempo_{name}.png"
    fig.savefig(out_path, dpi=120)
    print(f"plot saved to {out_path}")
    plt.show()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python mir/tempo.py <path to .wav>")
    main(sys.argv[1])
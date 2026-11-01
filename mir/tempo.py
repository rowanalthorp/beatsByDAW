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
# steps + numbers from the rhythm slides (slides 13-14) and section 2.2 of the same paper I used in onsets.py:
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
    our_bpm = bpms[np.argmax(enhanced)]
    # librosa's tempo as the baseline https://librosa.org/doc/latest/api/generated/librosa.feature.tempo.html
    librosa_bpm = float(librosa.feature.tempo(y=audio, sr=srate)[0])

    name = os.path.splitext(os.path.basename(path))[0]
    truth = true_tempo(name)
    truth_text = f"{truth:.1f}" if truth else "?"
    print(f"{name}: ours {our_bpm:.1f} BPM, librosa {librosa_bpm:.1f} BPM, true {truth_text} BPM")

    fig, ax = plt.subplots(figsize=(12, 4))
    ax.plot(bpms, enhanced, color="black", linewidth=0.8)
    ax.axvline(our_bpm, color="tab:red", label=f"ours {our_bpm:.1f}")
    ax.axvline(librosa_bpm, color="tab:blue", linestyle="--", label=f"librosa {librosa_bpm:.1f}")
    if truth:
        ax.axvline(truth, color="tab:green", linestyle=":", label=f"true {truth:.1f}")
    ax.set(title=f"{name}: enhanced beat histogram", xlabel="BPM", ylabel="strength", xlim=(50, 200))
    ax.legend(loc="upper right")
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
# obj 5 PI1: onset detection w/ spectral flux
# run from the repo root with the venv active:
#   python mir/onsets.py mir/data/BallroomData/ChaChaCha/Albums-Fire-08.wav
#
# cuts the audio into short overlapping slices (1024 samples, new slice every 128 = ~3 ms apart)
# and takes the log spectrum of each. then adds up how much the spectrum grew from one slice to
# the next, which gives the "onset strength" curve, and smooths it with a light low-pass filter.
# onsets (where a note/drum hit starts) are the peaks of that curve.
# peaks get picked w/ librosa's own peak picker, so comparing against librosa only tests our
# curve vs theirs. ballroom has no onset labels, so the printed score is agreement w/ librosa,
# not accuracy.
#
# pipeline is from the rhythm slides (slides 11-12), and then I found the related paper behind the slides:
# https://webhome.csc.uvic.ca/~gtzan/output/icassp2013tempo_gtzan.pdf (section 2.1)

import os
import sys

import librosa
import matplotlib.pyplot as plt
import mir_eval
import numpy as np
from scipy.signal import firwin, lfilter

# sample rate + window/hop sizes from rhythm slide 11
srate = 44100
win_size = 1024    # samples per slice
hop_size = 128     # samples between slice starts


def onset_strength(audio, srate=44100, win_size=1024, hop_size=128):
    curve_rate = srate / hop_size   # onset strength values per second (~344.5)

    # magnitude spectrum of each slice (rows = frequency bins, columns = slices), hamming window like the paper
    magnitudes = np.abs(librosa.stft(audio, n_fft=win_size, hop_length=hop_size, window="hamming")) # 2D grid
    # log compression ln(1 + 1000|X|) from the paper, so quieter hits still show up
    log_magnitudes = np.log1p(1000.0 * magnitudes)

    # only count bins that got louder since the last slice (= new sound starting)
    got_louder = np.diff(magnitudes, axis=1) > 0 # bool matrix: true if that frequency is louder than in the previous slice/column
    flux = np.sum(np.diff(log_magnitudes, axis=1) * got_louder, axis=0)
    flux = np.concatenate([[0.0], flux]) # pad so there's one value per slice

    # smooth out jitter: 7th order FIR low-pass (8 taps), 30 Hz cutoff, hamming design, from the paper
    lowpass = firwin(8, 30.0, fs=curve_rate, window="hamming")
    return lfilter(lowpass, [1.0], flux) # low-pass filter used


def detect_onsets(onset_curve, srate=44100, hop_size=128):
    # librosa's peak picker on our curve, so comparing w/ librosa only tests the curve itself
    # https://librosa.org/doc/latest/api/generated/librosa.onset.onset_detect.html
    return librosa.onset.onset_detect(onset_envelope=onset_curve, sr=srate, hop_length=hop_size, units="time")


# for showcase purposes
def plot_onsets(name, audio, onset_curve, our_onsets, librosa_onsets, srate=44100, hop_size=128):
    # top: waveform w/ both sets of onsets, bottom: our curve w/ the picked peaks
    audio_times = np.arange(len(audio)) / srate
    curve_times = np.arange(len(onset_curve)) * hop_size / srate
    fig, (wave_ax, curve_ax) = plt.subplots(2, 1, figsize=(12, 6), sharex=True)
    wave_ax.plot(audio_times, audio, color="0.6", linewidth=0.5)
    wave_ax.vlines(our_onsets, -1, 0, color="tab:red", linewidth=0.8, label="ours")
    wave_ax.vlines(librosa_onsets, 0, 1, color="tab:blue", linewidth=0.8, label="librosa")
    wave_ax.set(title=f"{name}: onsets", ylabel="amplitude")
    wave_ax.legend(loc="upper right")
    curve_ax.plot(curve_times, onset_curve, color="black", linewidth=0.7)
    curve_ax.plot(our_onsets, np.interp(our_onsets, curve_times, onset_curve), "o", color="tab:red", markersize=3)
    curve_ax.set(title="onset strength (spectral flux)", xlabel="time (s)", ylabel="strength")
    fig.tight_layout()
    return fig


def main(path):
    audio, _ = librosa.load(path, sr=srate, mono=True)

    onset_curve = onset_strength(audio, srate, win_size, hop_size)
    our_onsets = detect_onsets(onset_curve, srate, hop_size)
    librosa_onsets = librosa.onset.onset_detect(y=audio, sr=srate, units="time")   # librosa's full pipeline = baseline

    # how well ours lines up w/ librosa's, 50 ms tolerance (mir_eval's default for onsets)
    # https://mir-eval.readthedocs.io/latest/api/onset.html
    f_score, precision, recall = mir_eval.onset.f_measure(librosa_onsets, our_onsets, window=0.05)
    name = os.path.splitext(os.path.basename(path))[0]
    print(f"{name}: ours {len(our_onsets)} onsets, librosa {len(librosa_onsets)} onsets")
    print(f"agreement with librosa (50 ms window): F={f_score:.2f}  P={precision:.2f}  R={recall:.2f}")

    fig = plot_onsets(name, audio, onset_curve, our_onsets, librosa_onsets, srate, hop_size)
    os.makedirs("mir/out", exist_ok=True)
    out_path = f"mir/out/onsets_{name}.png"
    fig.savefig(out_path, dpi=120)
    print(f"plot saved to {out_path}")
    plt.show()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python mir/onsets.py <path to .wav>")
    main(sys.argv[1])
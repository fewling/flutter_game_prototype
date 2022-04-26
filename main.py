import os
import sys
import librosa

# https://musicinformationretrieval.com/onset_detection.html


def main():
    print('Argument List:', str(sys.argv))
    file_path = sys.argv[1]
    # file_path = 'assets\Amine - Invincible _ Spider-Man_ Into the Spider-Verse OST.flac'
    x, sr = librosa.load(file_path)
    onset_frames = librosa.onset.onset_detect(
        x, sr=sr, wait=1, pre_avg=1, post_avg=1, pre_max=1, post_max=1)
    onset_times = librosa.frames_to_time(onset_frames)

    # remove extension, .mp3, .wav etc.
    file_name_no_extension, _ = os.path.splitext(file_path)
    output_name = file_name_no_extension + '.beatmap.txt'
    with open(output_name, 'wt') as f:
        f.write('\n'.join(['%.4f' % onset_time for onset_time in onset_times]))


if __name__ == '__main__':
    main()

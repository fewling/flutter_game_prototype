import json
import os
import random
import sys
import librosa

# https://musicinformationretrieval.com/onset_detection.html


def main():
    print('Argument List:', str(sys.argv))
    my_json = {}
    file_path = sys.argv[1]
    my_json['file'] = file_path

    x, sr = librosa.load(file_path)
    onset_frames = librosa.onset.onset_detect(
        x, sr=sr, wait=1, pre_avg=1, post_avg=1, pre_max=1, post_max=1)
    onset_times = librosa.frames_to_time(onset_frames)

    keys = ['A', 'S', 'D', 'J', 'K', 'L']
    pressed_keys = []

    for i in range(len(onset_times)):
        pressed_keys.append(
            {random.choice(keys): round(onset_times[i] * 1000)})

    my_json['pressed_keys'] = pressed_keys

    # remove extension, .mp3, .wav etc.
    file_name_no_extension, _ = os.path.splitext(file_path)
    output_name = file_name_no_extension + '.json'
    with open(output_name, 'w') as f:
        json.dump(my_json, f, indent=4)


if __name__ == '__main__':
    main()

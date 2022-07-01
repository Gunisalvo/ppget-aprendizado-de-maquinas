import pandas as pd
import numpy as np
from functools import reduce


class DataSource:

    def __init__(self, filename, size=(30*24*60), step=0.1, sample_frequency="5min", features=None):
        if features is None:
            features = ["Global_active_power"]
        self.baseframe = pd.read_csv(filename, delimiter=";", na_values="?", iterator=True)
        self.index = 0
        self.size = size
        self.step = step
        self.sample_frequency = sample_frequency
        self.features = features
        self.frame = pd.DataFrame()

    def __iter__(self):
        return self

    def _next_frame(self):
        if self.frame.empty:
            dataframe = self.baseframe.get_chunk(self.size)
            step_size = 0
        else:
            step_size = int(self.size * self.step)
            dataframe = self.baseframe.get_chunk(step_size)

        dataframe = dataframe.fillna(dataframe.median(numeric_only=True))
        dataframe["timestamp"] = pd.to_datetime(dataframe["Date"] + " " + dataframe["Time"], format="%d/%m/%Y %H:%M:%S")
        dataframe = dataframe.set_index("timestamp")

        def resample_feature(acc, feature):
            frame = dataframe[feature].resample(self.sample_frequency).mean()
            acc["index"] = frame.index
            series = acc.get("series", [])
            series.append(frame.tolist())
            acc["series"] = series
            return acc

        resampled_features = reduce(resample_feature, self.features, {})

        frame = pd.DataFrame(resampled_features["series"]).T
        frame.index = resampled_features["index"]
        frame.columns = self.features

        if not self.frame.empty and step_size > 0:
            slide_size = len(self.frame.index) - len(frame.index)
            first_part = self.frame.tail(slide_size)
            result = pd.concat([first_part, frame])
            result_index = np.concatenate([first_part.index, frame.index])
            result.index = result_index
        else:
            result = frame

        return result

    def __next__(self):
        self.index += 1
        self.frame = self._next_frame()
        print(f"{self.frame.index[0]} -> {self.frame.index[-1]}")
        return self

    def generate_window(self, train_test_split, sequence_length):
        return WindowGenerator(train_test_split, sequence_length, self.frame)


def normalise_window(window, single=False):
    normalised = []
    window = [window] if single else window
    for w in window:
        normalised_window = []
        for i in range(w.shape[1]):
            normalised_column = [((float(p) / float(w[0, i])) - 1) for p in w[:, i]]
            normalised_window.append(normalised_column)
        normalised_window = np.array(normalised_window).T
        normalised.append(normalised_window)
    return np.array(normalised)


class WindowGenerator:

    def __init__(self, train_test_split, sequence_length, df, steps=12):
        self.sequence_length = sequence_length
        self.split_size = int(len(df) * train_test_split)
        self.train_frame = df.values[:self.split_size]
        self.test_frame = df.values[self.split_size:]
        self.steps = steps

    def train_data(self, normalise):
        X_train = []
        y_train = []
        for n in range(len(self.train_frame) - (self.sequence_length + self.steps)):
            X, y = self._next_window(n, normalise)
            X_train.append(X)
            y_train.append(y)
        return np.array(X_train), np.array(y_train)

    def _next_window(self, n, normalise):
        window_and_labels = self.train_frame[n:n + self.sequence_length + self.steps]
        window = normalise_window(window_and_labels, single=True)[0] if normalise else window_and_labels
        X = window[:-(self.steps + 1)]
        y = window[-(self.steps + 1):, [0]]
        return X, y

    def test_data(self, normalise):
        windows = []
        for n in range(len(self.test_frame) - (self.sequence_length + self.steps)):
            windows.append(self.test_frame[n:n + self.sequence_length])
        labels = np.array(windows).astype(float)
        normalised_labels = normalise_window(labels, single=False) if normalise else labels

        X = normalised_labels[:, :-1]
        y = normalised_labels[:, -(self.steps + 1):, [0]]
        return X, y

    def baseline(self, data):
        return list(map(lambda x: x[-2][0], data))

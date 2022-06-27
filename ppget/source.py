import pandas as pd
import numpy as np
from functools import reduce


class DataSource:

    def __init__(self, filename, size=(30*24*60), step=0.1, sample_frequency="10min", features=None):
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


def normalise_windows(window_data, single_window=False):
    normalised_data = []
    window_data = [window_data] if single_window else window_data
    for w in window_data:
        normalised_window = []
        for i in range(w.shape[1]):
            normalised_column = [((float(p) / float(w[0, i])) - 1) for p in w[:, i]]
            normalised_window.append(normalised_column)
        normalised_window = np.array(normalised_window).T
        normalised_data.append(normalised_window)
    return np.array(normalised_data)


class WindowGenerator:

    def __init__(self, train_test_split, sequence_length, df):
        self.sequence_length = sequence_length
        self.split_size = int(len(df) * train_test_split)
        self.train_frame = df.values[:self.split_size]
        self.test_frame = df.values[self.split_size:]

    def train_data(self, normalise):
        X_train = []
        y_train = []
        for n in range(len(self.train_frame) - self.sequence_length):
            X, y = self._next_window(n, normalise)
            X_train.append(X)
            y_train.append(y)
        return np.array(X_train), np.array(y_train)

    def _next_window(self, n, normalise):
        window = self.train_frame[n:n + self.sequence_length]
        window = normalise_windows(window, single_window=True)[0] if normalise else window
        X = window[:-1]
        y = window[-1, [0]]
        return X, y

    def test_data(self, normalise):
        windows = []
        for n in range(len(self.test_frame) - self.sequence_length):
            windows.append(self.test_frame[n:n + self.sequence_length])
        labels = np.array(windows).astype(float)
        normalised_labels = normalise_windows(labels, single_window=False) if normalise else labels

        X = normalised_labels[:, :-1]
        y = normalised_labels[:, -1, [0]]
        return X, y


# if __name__ == "__main__":
#     A_DAY = 60 * 24
#     DAYS_OF_DATA = 30
#
#     WINDOW = 25
#     BATCH_SIZE = 32
#     LEARNING_RATE = 0.00075
#
#     s = DataSource("../data/household_power_consumption.txt", size=DAYS_OF_DATA * A_DAY, step=0.33)
#     score_evolution = []
#     score_evolution2 = []
#
#     online_model = Model(name="online", model_type="cnn1d", window=WINDOW)
#     online_model.compile(LEARNING_RATE)
#     for _ in range(0, 50):
#         f = s.__next__()
#
#         window = f.generate_window(0.9, WINDOW)
#         try:
#             X_train, y_train = window.train_data(True)
#             X_test, y_test = window.test_data(True)
#         except Exception as _:
#             break
#         print(f"{X_train.shape}, {y_train.shape} : {X_test.shape}, {y_test.shape}")
#
#         batch_model = Model(name="batch", model_type="cnn1d", window=WINDOW)
#         batch_model.compile(LEARNING_RATE)
#
#         online_model.fit(
#             X_train,
#             y_train,
#             batch_size=BATCH_SIZE
#         )
#
#         batch_model.fit(
#             X_train,
#             y_train,
#             batch_size=BATCH_SIZE)
#
#         predictions = online_model.predict(X_test)
#         predictions2 = batch_model.predict(X_test)
#
#         score_evolution.append(r2_score(predictions, y_test))
#         score_evolution2.append(r2_score(predictions2, y_test))
#
#         plt.clf()


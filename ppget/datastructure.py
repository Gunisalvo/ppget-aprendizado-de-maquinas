import numpy as np
from sklearn.preprocessing import MinMaxScaler


class TrainSplit:

    def __init__(self, train, validation=0.0):
        self.train = train
        self.validation = validation

    def split(self, X, y):
        l = len(X)
        b1 = int(l * self.train)
        b2 = int(b1 + (l * self.validation))

        X_train, y_train = X[:b1], y[:b1]
        X_val, y_val = X[b1:b2], y[b1:b2]
        X_test, y_test = X[b2:], y[b2:]

        return {
            "training": {"X": X_train, "y": y_train},
            "validation": {"X": X_val, "y": y_val},
            "test": {"X": X_test, "y": y_test}
        }


class DatasetBuilder:

    __scaler = MinMaxScaler(feature_range=(0, 1))

    def __init__(self, X, window_size=48, all_features=False, data_split=TrainSplit(0.9), normalised=True):
        self.data_split = data_split

        if normalised:
            values = X.values.reshape((len(X.values), 1))
            self.__normaliser = self.__scaler.fit(values)
            self.__original_frame = self.__normaliser.transform(values).flatten()
        else:
            self.__original_frame = X.to_numpy()

        vector_frame = self.__original_frame
        X = []
        y = []
        if all_features:
            for i in range(len(vector_frame) - window_size):
                row = [r for r in vector_frame[i:i + window_size]]
                X.append(row)
                label = vector_frame[i + window_size][0]
                y.append(label)
            self.X = np.array(X)
            self.y = np.array(y)
        else:
            for i in range(len(vector_frame) - window_size):
                row = [[a] for a in vector_frame[i:i + window_size]]
                X.append(row)
                label = vector_frame[i + window_size]
                y.append(label)
            self.X = np.array(X)
            self.y = np.array(y)

    def build_splits(self):
        return self.data_split.split(self.X, self.y)

    def denormalise(self, X):
        if self.__normaliser:
            return self.__normaliser.inverse_transform(X.reshape((len(X), 1))).flatten()
        else:
            return X


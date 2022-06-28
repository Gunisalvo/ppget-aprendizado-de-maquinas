import os
import numpy as np
from keras.layers import Dense, Dropout, Conv1D, Flatten, InputLayer, LSTM, GRU
from keras.models import Sequential
from keras.optimizers import Adam
from keras.callbacks import EarlyStopping, ModelCheckpoint


def __FFNN(model, neurons, dropout):
    model.add(Dense(neurons, 'relu'))
    model.add(Flatten())
    model.add(Dropout(dropout))
    model.add(Dense(neurons, 'relu'))
    model.add(Dense(1, 'linear'))


def __CNN1D(model, neurons, dropout):
    model.add(Conv1D(neurons, kernel_size=2, activation="relu"))
    model.add(Dropout(dropout))
    model.add(Flatten())
    model.add(Dense(neurons, "relu"))
    model.add(Dense(1, "linear"))


def __LSTM(model, neurons, dropout):
    model.add(LSTM(neurons, return_sequences=False, dropout=dropout))
    model.add(Dense(neurons, 'relu'))
    model.add(Dense(1, 'linear'))


def __GRU(model, neurons, dropout):
    model.add(GRU(neurons))
    model.add(Dropout(dropout))
    model.add(Dense(neurons, 'relu'))
    model.add(Dense(1, 'linear'))


MODEL_STRUCTURE = {
    "ffnn": __FFNN,
    "cnn1d": __CNN1D,
    "lstm": __LSTM,
    "gru": __GRU
}


class Model:

    def __init__(self, name, model_type, window, neurons=8, dropout=0.02, patience=4, monitor="val_loss"):

        self.model = Sequential()
        self.model.add(InputLayer((window - 1, 1)))
        self.name = name

        MODEL_STRUCTURE[model_type](self.model, neurons, dropout)
        model_file_name = os.path.join(f"model/{self.name}-{model_type}", f"w{window}n{neurons}d{dropout}.model")
        self.callbacks = [
            EarlyStopping(monitor=monitor, patience=patience),
            ModelCheckpoint(filepath=model_file_name, monitor=monitor, save_best_only=True)
        ]

    def compile(self, learning_rate=0.0001, loss_function="mse"):
        self.model.compile(loss=loss_function, optimizer=Adam(learning_rate=learning_rate, amsgrad=True))

    def fit(self, X, y, batch_size=64, validation_split=0.2, epochs=100):
        self.model.fit(
            X,
            y,
            validation_split=validation_split,
            epochs=epochs,
            batch_size=batch_size,
            callbacks=self.callbacks
        )

    def predict(self, data):
        predicted = self.model.predict(data)
        predicted = np.reshape(predicted, (predicted.size,))
        return predicted

    def describe(self):
        self.model.summary()

    @staticmethod
    def baseline(data):
        return list(map(lambda x: x[-2][0], data))

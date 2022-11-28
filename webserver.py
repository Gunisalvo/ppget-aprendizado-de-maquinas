from flask import Flask, json, request
from ppget.source import DataSource
import os, sys
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
import tensorflow as tf
import logging
tf.get_logger().setLevel(logging.ERROR)

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

# Timeseries Dataset
A_DAY = 60 * 24
DAYS_OF_DATA = 270
logger.info(f"Initializing dataset with: {DAYS_OF_DATA} days")
# [step] marks the percentage of time advance proportional to the data cursor [size]
source = DataSource("./data/household_power_consumption.txt", size=DAYS_OF_DATA * A_DAY, step=0.33)
time_series = next(source)
logger.info("... done.")

# ML Model
WINDOW = 48
logger.info(f"Initializing ML model: sequence size {WINDOW}")
smart_meter_model = tf.keras.models.load_model(f"{os.getcwd()}/model/test-cnn1d/w48n4d0.02.model")
meter_readings = time_series.generate_window(0.99, WINDOW)
logger.info("... done.")
logger.info("Precomputing predictions")
X_train, _ = meter_readings.train_data(True)
X_test, _ = meter_readings.test_data(True)

global_active_power = X_test[:, -1, :]
forecasts = smart_meter_model.predict(X_train)
no_forecast = X_test[:, -1, :]
available_positions = len(global_active_power)
logger.info(f"{available_positions} position available.")

# REST API
api = Flask(__name__)


@api.route('/smart-meter/<series_position>', methods=['GET'])
def get_active_power(series_position):
    alfa = 0.009
    gama = -0.0023

    def rescale(x):
        return (alfa * x) + gama

    series_position = int(series_position)
    forecast_enabled = request.args.get('forecast-enabled', None)
    logger.info(f"Evaluating position {series_position}, forecast: {forecast_enabled}")
    # Re-initiate the cycle in case of overflow
    cycle_position = series_position % available_positions

    if forecast_enabled:
        active_power = float(global_active_power[cycle_position][0])
        forecast = float(forecasts[cycle_position][0])
    else:
        active_power = float(global_active_power[cycle_position][0])
        forecast = float(no_forecast[cycle_position][0])
    logger.info(f"Result: {rescale(active_power)}  -> {rescale(forecast)}")

    return f"[{rescale(active_power)} {rescale(forecast)}]"


if __name__ == '__main__':
    # Check model architecture
    logger.debug(smart_meter_model.summary())
    # Timeseries
    logger.debug(time_series.frame.head())

    api.run(port=9171)

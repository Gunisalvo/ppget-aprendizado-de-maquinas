import pandas as pd


class ModelSource:

    __structure = {
        "Time": str,
        "Date": str,
        "Global_active_power": float,
        "Global_reactive_power": float,
        "Voltage": float,
        "Global_intensity": float,
        "Sub_metering_1": float,
        "Sub_metering_2": float,
        "Sub_metering_3": float
    }

    __datasource = None

    def __init__(self, start_date, end_date, feature, frequency, path, cleaning_backfill):
        def seasonal_fill(s):
            return s.fillna(s.shift(-24 * cleaning_backfill))

        def clean_data(dataframe):
            date_range = (dataframe["date_filter"] >= start_date) & (dataframe["date_filter"] < end_date)
            return dataframe.dropna(subset=[feature]).loc[date_range][feature].resample(frequency).mean()

        data = pd.read_csv(path,
                           header=0,
                           squeeze=True,
                           delimiter=";",
                           na_values=["?"],
                           dtype=self.__structure)

        data["timestamp"] = pd.to_datetime(data["Date"] + " " + data["Time"], format="%d/%m/%Y %H:%M:%S")
        data["date_filter"] = pd.to_datetime(data["Date"] + " " + data["Time"],
                                             format="%d/%m/%Y %H:%M:%S")
        data = data.set_index("timestamp")
        self.__datasource = seasonal_fill(clean_data(data))

    def missing_data(self):
        return self.__datasource[self.__datasource.isnull()]

    def series(self):
        return self.__datasource

    @staticmethod
    def load(start_date, end_date, feature, frequency="1H", path="./data/household_power_consumption.txt", cleaning_backfill=1):
        return ModelSource(start_date, end_date, feature, frequency, path, cleaning_backfill)

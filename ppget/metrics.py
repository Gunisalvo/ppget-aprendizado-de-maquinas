from sklearn.metrics import mean_squared_error, r2_score
from pathlib import Path
import numpy as np


class ModelEvaluation:

    def __init__(self, expected, predicted, m=1, model_path=None, builder=None):
        n = len(expected)
        base_rmse = np.sqrt(mean_squared_error(expected, predicted))
        self.rmse = builder.denormalise(np.array([base_rmse]))[0] if builder else base_rmse
        self.r2 = r2_score(expected, predicted)
        self.adj_r2 = 1 - ((1 - self.r2) * ((n - 1) / (n - m - 1)))
        self.size = sum(file.stat().st_size for file in Path(model_path).rglob('*')) if model_path else 0

    def __str__(self):
        return f"Model Scores - (R2): {self.r2:.3f}, " \
               f"(Adj R2): {self.adj_r2:.3f}, " \
               f"(RMSE): {self.rmse:.3f} KW. " \
               f"Model Size - {self.size} bytes."

import matplotlib.pyplot as plt
import numpy as np
from sklearn.metrics import mean_squared_error, r2_score
from scipy.stats import ttest_ind
from pathlib import Path


def report_case(X_test, y_test, predictions, model, case, render=True):
    baseline = np.append(X_test[case][-1], [X_test[case][-1] for _ in range(len(y_test[case]))])
    l = np.append(X_test[case][-1], y_test[case])
    p = np.append(X_test[case][-1], predictions[case])

    def render_report(input_, expected, predicted, baseline):
        plt.figure(figsize=(12, 8), dpi=110)
        plt.ylabel("KW (normalised)")
        plt.xlabel("5 min increment")
        plt.plot(input_, label='Input', color='blue', marker='o')
        plt.plot(range(len(input_) - 1, len(input_) + len(predicted) - 1), predicted,
                 label='Prediction', color='orange', marker='o')
        plt.plot(range(len(input_) - 1, len(input_) + len(expected) - 1), expected,
                 label='Label', color='cyan', marker='o')
        plt.plot(range(len(input_) - 1, len(input_) + len(expected) - 1), baseline,
                 label='Baseline', color='red', marker='o')
        plt.legend()
        plt.savefig(f"img/output_{case}_{model}.png")
        plt.show()

    if render:
        render_report(X_test[case], l, p, baseline)

    # Check if predictions are significantly different from the baseline
    _, p_value = ttest_ind(baseline[1:], p[1:])
    # Check MSE for model and baseline
    mse_baseline = mean_squared_error(l[1:], baseline[1:])
    mse_model = mean_squared_error(l[1:], p[1:])

    return mse_baseline, mse_model, p_value


def report_best_case(X_test, y_test, predictions, model_type, render=True):
    best_case = 0
    best_error = np.Infinity
    best_difference = 0

    for case in range(len(X_test)):
        b_error, m_error, p_value = report_case(X_test, y_test, predictions, model_type, case, render=False)
        if m_error < best_error and p_value < 0.05:
            if b_error - m_error > best_difference:
                best_case = case
                best_error = m_error
                best_difference = b_error - m_error

    mse_baseline, mse_model, p_value = report_case(X_test, y_test, predictions, model_type, best_case, render=render)

    return best_case, mse_baseline, mse_model, p_value


def report_results(expected, predicted, model=None, window=None, range_limit=None, render=True):
    e = list(map(lambda x: np.mean(x), expected))
    p = list(map(lambda x: np.mean(x), predicted))

    def render_report():
        plt.figure(figsize=(12, 8), dpi=110)
        if range_limit:
            plt.xlim(range_limit)
        plt.plot(e, label='Ground Truth')
        plt.plot(p, label='Prediction')
        plt.ylabel("KW (normalised)")
        plt.xlabel("5 min increment")
        plt.legend()
        plt.savefig(f"img/model_{model}_{window}_{range_limit}.png")
        plt.show()

    if render:
        render_report()

    return r2_score(e, p)


def report_model_size(model_path):
    return sum(file.stat().st_size for file in Path(model_path).rglob('*')) if model_path else 0

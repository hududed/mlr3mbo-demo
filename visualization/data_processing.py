from sklearn.decomposition import PCA
import pandas as pd
import numpy as np
from scipy.interpolate import griddata


def read_data(file_path):
    return pd.read_csv(file_path)


def perform_pca(data, columns):
    pca = PCA(n_components=2)
    pca_result = pca.fit_transform(data[columns])
    data["PC1"] = pca_result[:, 0]
    data["PC2"] = pca_result[:, 1]
    return data


def define_grid(data, num_points):
    x = np.linspace(data["PC1"].min(), data["PC1"].max(), num_points)
    y = np.linspace(data["PC2"].min(), data["PC2"].max(), num_points)
    return np.meshgrid(x, y)


def interpolate_data(data, x_grid, y_grid, column):
    return griddata(
        (data["PC1"], data["PC2"]), data[column], (x_grid, y_grid), method="cubic"
    )


def create_weighted_sum(data, weight1, weight2, column1, column2):
    data["Weighted Sum"] = weight1 * data[column1] + weight2 * data[column2]
    return data


def clean_column_names(data):
    # Perform the cleaning
    cleaned_columns = (
        data.columns.str.strip()
        .str.lower()
        .str.replace(" ", "_")
        .str.replace("(", "", regex=False)
        .str.replace(")", "", regex=False)
        .str.replace("#", "number")
        .str.replace("°c", "c")
        .str.replace("j/g", "j_per_g")
        .str.replace("at%", "at_percent")
    )

    # Create a dictionary that maps the old names to the new ones
    column_mapping = dict(zip(data.columns, cleaned_columns))

    # Replace the column names in place
    data.rename(columns=column_mapping, inplace=True)

    return data

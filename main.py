# %%
# pip install selenium
# brew install geckodriver

# in colab
# !apt-get update
#!apt install -y xvfb firefox
#!pip install selenium pyvirtualdisplay

# Download and install geckodriver
#!wget https://github.com/mozilla/geckodriver/releases/download/v0.34.0/geckodriver-v0.34.0-linux64.tar.gz
#!tar -xvzf geckodriver-v0.34.0-linux64.tar.gz
#!chmod +x geckodriver
#!mv geckodriver /usr/local/bin/

# %%


from bokeh.models import LinearColorMapper
from bokeh.models import (
    ColumnDataSource,
    LinearColorMapper,
)
from visualization.data_processing import (
    read_data,
    perform_pca,
    define_grid,
    interpolate_data,
    create_weighted_sum,
    clean_column_names,
)
from visualization.plotting import (
    create_hover_tool,
    create_figure,
    add_image_glyph,
    add_circle_glyph,
    add_color_bar,
    show_figure,
    save_figure,
)
import numpy as np

# Read the data
data = read_data("CuAlMnNi-data.csv")
print(data.columns)

data = clean_column_names(data)

print(data.columns)

# %%
# Perform PCA
data = perform_pca(
    data, ["cu_at_percent", "al_at_percent", "mn_at_percent", "ni_at_percent"]
)

# Define the grid
num_points = 500
x = np.linspace(data["PC1"].min(), data["PC1"].max(), num_points)
y = np.linspace(data["PC2"].min(), data["PC2"].max(), num_points)
x_grid, y_grid = define_grid(data, num_points)


# Check for duplicates in the 'cu_at_percent', 'al_at_percent', 'mn_at_percent', 'ni_at_percent' columns
duplicates = data[
    ["cu_at_percent", "al_at_percent", "mn_at_percent", "ni_at_percent"]
].duplicated(keep=False)

# Print the number of duplicates
print(f"Number of duplicate rows: {duplicates.sum()}")

# If you want to see the actual duplicate rows:
print("Duplicate Rows:")
data[duplicates]


# Interpolate the DSC Af values
z1 = interpolate_data(data, x_grid, y_grid, "dsc_af_c")

# Interpolate the Enthalpy values
z2 = interpolate_data(data, x_grid, y_grid, "enthalpy_j_per_g")

# Create a weighted sum of the "dsc_af_c" and "enthalpy_j_per_g" columns
data = create_weighted_sum(data, 0.5, 0.5, "dsc_af_c", "enthalpy_j_per_g")

# Interpolate the weighted sum values
z4 = interpolate_data(data, x_grid, y_grid, "Weighted Sum")

# Create a color mapper for DSC Af
SENTINEL_VALUE = -9999
color_mapper1 = LinearColorMapper(
    palette="Viridis256",
    low=np.min(z1[z1 > SENTINEL_VALUE]),
    high=np.max(z1[z1 > SENTINEL_VALUE]),
    nan_color="white",
)

# Create a color mapper for Enthalpy
color_mapper2 = LinearColorMapper(
    palette="Inferno256",
    low=np.min(z2[z2 > SENTINEL_VALUE]),
    high=np.max(z2[z2 > SENTINEL_VALUE]),
    nan_color="white",
)

color_mapper4 = LinearColorMapper(
    palette="Turbo256",
    low=np.min(z4[z4 > SENTINEL_VALUE]),
    high=np.max(z4[z4 > SENTINEL_VALUE]),
    nan_color="white",
)

# Create a ColumnDataSource from data
source = ColumnDataSource(data)

# Create a hover tool
hover = create_hover_tool(
    [
        ("Cu", "@cu_at_percent"),
        ("Al", "@al_at_percent"),
        ("Mn", "@mn_at_percent"),
        ("Ni", "@ni_at_percent"),
        ("DSC Af", "@dsc_af_c"),
        ("Enthalpy", "@enthalpy_j_per_g"),
    ]
)

# Create a new plot for DSC Af
p1 = create_figure(
    hover, (x.min(), x.max()), (y.min(), y.max()), "PCA and Interpolation of DSC Af"
)


# Add the image glyph for DSC Af
add_image_glyph(
    p1,
    [z1],
    (x.min(), x.max()),
    (y.min(), y.max()),
    color_mapper1,
    "Interpolated DSC Af",
)

# Add a circle renderer with vectorized colors and sizes and a legend
add_circle_glyph(p1, source, "Data Points")
# Add a color bar for DSC Af
add_color_bar(p1, color_mapper1)

# Show the plot
show_figure(p1)

# Save the plots as PNG images
save_figure(p1, "plot1.png")

# Repeat the process for the other plots
p2 = create_figure(
    hover, (x.min(), x.max()), (y.min(), y.max()), "PCA and Interpolation of Enthalpy"
)
add_image_glyph(
    p2,
    [z2],
    (x.min(), x.max()),
    (y.min(), y.max()),
    color_mapper2,
    "Interpolated Enthalpy",
)
add_circle_glyph(p2, source, "Data Points")
add_color_bar(p2, color_mapper2)
show_figure(p2)
save_figure(p2, "plot2.png")

p4 = create_figure(
    hover,
    (x.min(), x.max()),
    (y.min(), y.max()),
    "PCA and Interpolation of Weighted Sum",
)
add_image_glyph(
    p4,
    [z4],
    (x.min(), x.max()),
    (y.min(), y.max()),
    color_mapper4,
    "Interpolated Weighted Sum",
)
add_circle_glyph(p4, source, "Data Points")
add_color_bar(p4, color_mapper4)
show_figure(p4)
save_figure(p4, "plot4.png")

# %%

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


# Set up the virtual display
# from pyvirtualdisplay import Display
# display = Display(visible=0, size=(1024, 768))
# display.start()
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

# Perform PCA
data = perform_pca(data, ["Cu (at%)", "Al (at%)", "Mn (at%)", "Ni (at%)"])

# Define the grid
x = np.linspace(data["PC1"].min(), data["PC1"].max(), 500)
y = np.linspace(data["PC2"].min(), data["PC2"].max(), 500)
x_grid, y_grid = define_grid(data, 500)

# Interpolate the DSC Af values
z1 = interpolate_data(data, x_grid, y_grid, "DSC Af (°C)")

# Interpolate the Enthalpy values
z2 = interpolate_data(data, x_grid, y_grid, "Enthalpy (J/g)")

# Create a weighted sum of the "DSC Af (°C)" and "Enthalpy (J/g)" columns
data = create_weighted_sum(data, 0.5, 0.5, "DSC Af (°C)", "Enthalpy (J/g)")

# Interpolate the weighted sum values
z4 = interpolate_data(data, x_grid, y_grid, "Weighted Sum")

# Create a color mapper for DSC Af
color_mapper1 = LinearColorMapper(
    palette="Viridis256",
    low=np.min(z1[z1 > -9999]),
    high=np.max(z1[z1 > -9999]),
    nan_color="white",
)

# Create a color mapper for Enthalpy
color_mapper2 = LinearColorMapper(
    palette="Viridis256",
    low=np.min(z2[z2 > -9999]),
    high=np.max(z2[z2 > -9999]),
    nan_color="white",
)

color_mapper4 = LinearColorMapper(
    palette="Viridis256",
    low=np.min(z4[z4 > -9999]),
    high=np.max(z4[z4 > -9999]),
    nan_color="white",
)

# Create a ColumnDataSource from data
source = ColumnDataSource(data)

# Create a hover tool
hover = create_hover_tool(
    [
        ("Cu", "@{Cu (at%)}"),
        ("Al", "@{Al (at%)}"),
        ("Mn", "@{Mn (at%)}"),
        ("Ni", "@{Ni (at%)}"),
        ("DSC Af", "@{DSC Af (°C)}"),
        ("Enthalpy", "@{Enthalpy (J/g)}"),
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


# # %%
# from bokeh.plotting import figure, show
# from bokeh.models import (
#     HoverTool,
#     ColumnDataSource,
#     LinearColorMapper,
#     ColorBar,
#     HoverTool,
# )
# from bokeh.io import output_notebook, export_png
# from sklearn.decomposition import PCA
# import pandas as pd
# import numpy as np
# from scipy.interpolate import griddata

# # Read the data
# data = pd.read_csv("CuAlMnNi-data.csv")

# # Perform PCA
# pca = PCA(n_components=2)
# pca_result = pca.fit_transform(data[["Cu (at%)", "Al (at%)", "Mn (at%)", "Ni (at%)"]])

# # Add the PCA results to the data frame
# data["PC1"] = pca_result[:, 0]
# data["PC2"] = pca_result[:, 1]

# # Define the grid
# x = np.linspace(data["PC1"].min(), data["PC1"].max(), 500)
# y = np.linspace(data["PC2"].min(), data["PC2"].max(), 500)
# x_grid, y_grid = np.meshgrid(x, y)

# # Interpolate the DSC Af values
# z1 = griddata(
#     (data["PC1"], data["PC2"]), data["DSC Af (°C)"], (x_grid, y_grid), method="cubic"
# )

# # Interpolate the Enthalpy values
# z2 = griddata(
#     (data["PC1"], data["PC2"]), data["Enthalpy (J/g)"], (x_grid, y_grid), method="cubic"
# )

# # Define the weights
# weight1 = 0.5
# weight2 = 0.5

# # Create a weighted sum of the "DSC Af (°C)" and "Enthalpy (J/g)" columns
# data["Weighted Sum"] = weight1 * data["DSC Af (°C)"] + weight2 * data["Enthalpy (J/g)"]

# # Interpolate the weighted sum values
# z4 = griddata(
#     (data["PC1"], data["PC2"]), data["Weighted Sum"], (x_grid, y_grid), method="cubic"
# )


# # Create a ColumnDataSource from data
# source = ColumnDataSource(data)

# # Create a hover tool
# hover = HoverTool(
#     tooltips=[
#         ("Cu", "@{Cu (at%)}"),
#         ("Al", "@{Al (at%)}"),
#         ("Mn", "@{Mn (at%)}"),
#         ("Ni", "@{Ni (at%)}"),
#         ("DSC Af", "@{DSC Af (°C)}"),
#         ("Enthalpy", "@{Enthalpy (J/g)}"),
#     ]
# )

# # Create a new plot with the hover tool and a title
# p = figure(
#     tools=[hover],
#     x_range=(x.min(), x.max()),
#     y_range=(y.min(), y.max()),
#     title="PCA and Interpolation of CuAlMnNi Data",
# )

# # # Add a circle renderer with vectorized colors and sizes
# # p.circle("PC1", "PC2", source=source, fill_color="blue", size=5)

# # Replace NaN values with a specific number
# z1 = np.nan_to_num(z1, nan=-9999)
# z2 = np.nan_to_num(z2, nan=-9999)
# z4 = np.nan_to_num(z4, nan=-9999)


# # Create a color mapper for DSC Af
# color_mapper1 = LinearColorMapper(
#     palette="Viridis256",
#     low=np.min(z1[z1 > -9999]),
#     high=np.max(z1[z1 > -9999]),
#     nan_color="white",
# )

# # Create a color mapper for Enthalpy
# color_mapper2 = LinearColorMapper(
#     palette="Viridis256",
#     low=np.min(z2[z2 > -9999]),
#     high=np.max(z2[z2 > -9999]),
#     nan_color="white",
# )

# color_mapper4 = LinearColorMapper(
#     palette="Viridis256",
#     low=np.min(z4[z4 > -9999]),
#     high=np.max(z4[z4 > -9999]),
#     nan_color="white",
# )


# # Create a new plot for DSC Af
# p1 = figure(
#     tools=[hover],
#     x_range=(x.min(), x.max()),
#     y_range=(y.min(), y.max()),
#     title="PCA and Interpolation of DSC Af",
# )

# # Add the image glyph for DSC Af
# p1.image(
#     image=[z1],
#     x=x.min(),
#     y=y.min(),
#     dw=(x.max() - x.min()),
#     dh=(y.max() - y.min()),
#     color_mapper=color_mapper1,
#     legend_label="Interpolated DSC Af",
# )

# # Add a circle renderer with vectorized colors and sizes and a legend
# p1.circle(
#     "PC1", "PC2", source=source, fill_color="white", size=10, legend_label="Data Points"
# )

# # Add a color bar for DSC Af
# color_bar1 = ColorBar(color_mapper=color_mapper1, location=(0, 0))
# p1.add_layout(color_bar1, "right")

# # Create a new plot for Enthalpy
# p2 = figure(
#     tools=[hover],
#     x_range=(x.min(), x.max()),
#     y_range=(y.min(), y.max()),
#     title="PCA and Interpolation of Enthalpy",
# )

# # Add the image glyph for Enthalpy
# p2.image(
#     image=[z2],
#     x=x.min(),
#     y=y.min(),
#     dw=(x.max() - x.min()),
#     dh=(y.max() - y.min()),
#     color_mapper=color_mapper2,
#     legend_label="Interpolated Enthalpy",
# )

# # Add a circle renderer with vectorized colors and sizes and a legend
# p2.circle(
#     "PC1", "PC2", source=source, fill_color="white", size=10, legend_label="Data Points"
# )


# # Add a color bar for Enthalpy
# color_bar2 = ColorBar(color_mapper=color_mapper2, location=(0, 0))
# p2.add_layout(color_bar2, "right")

# # Create a new plot for the weighted sum values
# p4 = figure(
#     tools=[hover],
#     x_range=(x.min(), x.max()),
#     y_range=(y.min(), y.max()),
#     title="PCA and Interpolation of Weighted Sum",
# )

# # Add the image glyph for the weighted sum values
# p4.image(
#     image=[z4],
#     x=x.min(),
#     y=y.min(),
#     dw=(x.max() - x.min()),
#     dh=(y.max() - y.min()),
#     color_mapper=color_mapper4,
#     legend_label="Interpolated Weighted Sum",
# )

# # Add a circle renderer with vectorized colors and sizes and a legend
# p4.circle(
#     "PC1", "PC2", source=source, fill_color="white", size=10, legend_label="Data Points"
# )

# # Add a color bar for the weighted sum values
# color_bar4 = ColorBar(color_mapper=color_mapper4, location=(0, 0))
# p4.add_layout(color_bar4, "right")


# # Show the plots
# output_notebook()
# show(p1)
# show(p2)
# show(p4)

# # Save the plots as PNG images
# export_png(p1, filename="DSC_Af.png")
# export_png(p2, filename="Enthalpy.png")
# export_png(p4, filename="Weighted.png")


# %%

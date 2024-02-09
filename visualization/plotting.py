from bokeh.plotting import figure
from bokeh.models import (
    HoverTool,
    ColorBar,
)
from bokeh.io import output_notebook, export_png, show


def create_hover_tool(tooltips):
    return HoverTool(tooltips=tooltips)


def create_figure(hover_tool, x_range, y_range, title):
    return figure(
        tools=[hover_tool],
        x_range=x_range,
        y_range=y_range,
        title=title,
    )


def add_image_glyph(figure, image, x_range, y_range, color_mapper, legend_label):
    figure.image(
        image=image,
        x=x_range[0],
        y=y_range[0],
        dw=(x_range[1] - x_range[0]),
        dh=(y_range[1] - y_range[0]),
        color_mapper=color_mapper,
        legend_label=legend_label,
    )


def add_circle_glyph(figure, source, legend_label):
    figure.circle(
        "PC1",
        "PC2",
        source=source,
        fill_color="white",
        size=10,
        legend_label=legend_label,
    )


def add_color_bar(figure, color_mapper):
    color_bar = ColorBar(color_mapper=color_mapper, location=(0, 0))
    figure.add_layout(color_bar, "right")


def show_figure(figure):
    output_notebook()
    show(figure)


def save_figure(figure, filename):
    export_png(figure, filename=filename)

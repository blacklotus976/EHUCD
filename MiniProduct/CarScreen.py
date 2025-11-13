import random
import math
from kivy.uix.widget import Widget
from kivy.uix.label import Label
from kivy.uix.boxlayout import BoxLayout
from kivy.graphics import Color, Line, Ellipse, Rectangle
from kivy.clock import Clock
from kivy.metrics import dp
from kivy.core.window import Window
from kivy.core.text import Label as CoreLabel  # For drawing text on the canvas
from MiniProduct.BaseScreen import BaseScreen

COLOR_DICT = {
    "black": (0, 0, 0, 1),
    "white": (1, 1, 1, 1),
    "red": (1, 0, 0, 1),
    "green": (0, 1, 0, 1),
    "blue": (0, 0, 1, 1),
    "yellow": (1, 1, 0, 1),
    "cyan": (0, 1, 1, 1),
    "magenta": (1, 0, 1, 1),
    "gray": (0.5, 0.5, 0.5, 1),
    "orange": (1, 0.65, 0, 1),
    "purple": (0.5, 0, 0.5, 1),
    "brown": (0.65, 0.16, 0.16, 1),
    "pink": (1, 0.75, 0.8, 1),
    "lime": (0.75, 1, 0, 1),
    "navy": (0, 0, 0.5, 1),
    "teal": (0, 0.5, 0.5, 1),
    "olive": (0.5, 0.5, 0, 1),
}


class CircularMeter(Widget):
    def __init__(self, max_val, step, unit, scale: float = 1,
                 needle_color:str='red',   # Needle default red
                 level_color:str='white',    # Ticks and numbers white
                 background_color:str=None,       # Background fill, default None (black ring)
                 center_fill_color:str='white',      # Center fill behind value, default None (no fill)
                 center_value_color:str='blue',     # Center numeric value color, default same as levels
                 **kwargs):
        super().__init__(**kwargs)
        self.scale = scale

        self.radius = dp(120) * self.scale
        self.center_hole_radius = dp(40) * self.scale
        self.unit_font_size = dp(24) * self.scale
        self.tick_length_big = dp(10) * self.scale
        self.tick_length_small = dp(5) * self.scale
        self.font_size = dp(14) * self.scale

        self.min_val = 0
        self.max_val = max_val
        self.step = step
        self.substep = step / 2
        self.unit = unit
        self.current_value = 0

        self.needle_color = COLOR_DICT[needle_color] if needle_color is not None else None
        self.level_color = COLOR_DICT[level_color] if level_color is not None else None
        self.background_color = COLOR_DICT[background_color] if background_color is not None else None
        self.center_fill_color = COLOR_DICT[center_fill_color] if center_fill_color is not None else None
        self.center_value_color = COLOR_DICT[center_value_color]  if center_value_color is not None else self.level_color

        Clock.schedule_interval(self.update_display, 0.1)

    def update_display(self, *args):
        self.canvas.before.clear()
        self.canvas.clear()

        # 1. Background fills below all else
        with self.canvas.before:
            if self.background_color:
                Color(*self.background_color)
                Ellipse(pos=(self.center_x - self.radius, self.center_y - self.radius),
                        size=(self.radius * 2, self.radius * 2))
            if self.center_fill_color:
                Color(*self.center_fill_color)
                Ellipse(pos=(self.center_x - self.center_hole_radius, self.center_y - self.center_hole_radius),
                        size=(self.center_hole_radius * 2, self.center_hole_radius * 2))

        # 2. Circle with levels (ticks and numbers)
        with self.canvas:
            if not self.background_color:
                Color(0, 0, 0, 1)
                Line(circle=(self.center_x, self.center_y, self.radius), width=2)

            Color(*self.level_color)
            for val in range(self.min_val, self.max_val + 1, int(self.substep)):
                angle = self.value_to_angle(val)
                length = self.tick_length_big if val % self.step == 0 else self.tick_length_small
                width = 2 if val % self.step == 0 else 1

                x_outer = self.center_x + self.radius * math.cos(math.radians(angle))
                y_outer = self.center_y + self.radius * math.sin(math.radians(angle))
                x_inner = self.center_x + (self.radius - length) * math.cos(math.radians(angle))
                y_inner = self.center_y + (self.radius - length) * math.sin(math.radians(angle))

                Line(points=[x_inner, y_inner, x_outer, y_outer], width=width)

                if val % self.step == 0:
                    label_x = self.center_x + (self.radius - dp(25) * self.scale) * math.cos(math.radians(angle))
                    label_y = self.center_y + (self.radius - dp(25) * self.scale) * math.sin(math.radians(angle))

                    label = CoreLabel(text=f"{val}", font_size=self.font_size, color=self.level_color)
                    label.refresh()
                    texture = label.texture
                    Rectangle(texture=texture,
                              pos=(label_x - texture.width / 2, label_y - texture.height / 2),
                              size=texture.size)

            # 3. Needle
            self.draw_needle()

            # 5. Center value text (last to be topmost)
            label_text = f"{int(self.current_value)}\n{self.unit}"
            label = CoreLabel(text=label_text, font_size=self.unit_font_size, color=self.center_value_color)
            label.refresh()
            texture = label.texture
            Rectangle(texture=texture,
                      pos=(self.center_x - texture.width / 2, self.center_y - texture.height / 2),
                      size=texture.size)

    def draw_needle(self):
        angle = self.value_to_angle(self.current_value)
        needle_start_radius = self.center_hole_radius
        needle_end_radius = self.radius - dp(15) * self.scale

        start_x = self.center_x + needle_start_radius * math.cos(math.radians(angle))
        start_y = self.center_y + needle_start_radius * math.sin(math.radians(angle))
        end_x = self.center_x + needle_end_radius * math.cos(math.radians(angle))
        end_y = self.center_y + needle_end_radius * math.sin(math.radians(angle))

        Color(*self.needle_color)
        Line(points=[start_x, start_y, end_x, end_y], width=3 * self.scale)

    def value_to_angle(self, value):
        ratio = (value - self.min_val) / (self.max_val - self.min_val)
        return 150 - ratio * 300

    def update_value(self, new_value):
        self.current_value = max(self.min_val, min(new_value, self.max_val))




class BarMeter(Widget):
    def __init__(self, max_val, width=dp(20), **kwargs):
        super(BarMeter, self).__init__(**kwargs)
        self.current_value = 0
        self.max_val = max_val
        self.width = width
        self.height = dp(150)
        Clock.schedule_interval(self.update_display, 0.1)

    def update_display(self, *args):
        self.canvas.clear()
        with self.canvas:
            Color(0.2, 0.2, 0.2, 1)
            Rectangle(pos=(self.center_x - self.width / 2, self.center_y - self.height / 2),
                      size=(self.width, self.height))

            filled_height = (self.current_value / self.max_val) * self.height
            Color(0, 1, 0, 1)
            Rectangle(pos=(self.center_x - self.width / 2, self.center_y - self.height / 2),
                      size=(self.width, filled_height))

    def update_value(self, new_value):
        self.current_value = max(0, min(new_value, self.max_val))



class WhiteBackgroundBox(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        with self.canvas.before:
            Color(1, 1, 1, 1)  # White
            self.rect = Rectangle(size=self.size, pos=self.pos)
        self.bind(size=self._update_rect, pos=self._update_rect)

    def _update_rect(self, instance, value):
        self.rect.pos = self.pos
        self.rect.size = self.size


class CarScreen(BaseScreen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.layout = BoxLayout(orientation='horizontal', padding=dp(20), spacing=dp(20))

        # Left: Value box for other metrics
        self.value_box = WhiteBackgroundBox(orientation='vertical', size_hint_x=None, width=dp(160),
                                   padding=dp(10), spacing=dp(5))
        self.value_labels = {}
        self.layout.add_widget(self.value_box)

        # Left-center: bars for fuel, throttle, brakes
        self.bars_layout = BoxLayout(orientation='vertical', spacing=dp(20), size_hint_x=None, width=dp(100))

        self.fuel_label = Label(text="Fuel", size_hint_y=None, height=dp(24))
        self.fuel_bar = BarMeter(max_val=100, width=dp(20))
        self.bars_layout.add_widget(self.fuel_label)
        self.bars_layout.add_widget(self.fuel_bar)

        self.throttle_label = Label(text="Throttle", size_hint_y=None, height=dp(24))
        self.throttle_bar = BarMeter(max_val=100, width=dp(20))
        self.bars_layout.add_widget(self.throttle_label)
        self.bars_layout.add_widget(self.throttle_bar)

        self.brakes_label = Label(text="Brakes", size_hint_y=None, height=dp(24))
        self.brakes_bar = BarMeter(max_val=100, width=dp(20))
        self.bars_layout.add_widget(self.brakes_label)
        self.bars_layout.add_widget(self.brakes_bar)

        self.layout.add_widget(self.bars_layout)

        # Center: Big speedometer
        self.speedometer_box = BoxLayout(orientation='vertical', size_hint=(.5, 1))
        self.speedometer = CircularMeter(max_val=200, step=10, unit='km/h')
        self.speedometer_box.add_widget(self.speedometer)
        self.layout.add_widget(self.speedometer_box)

        # Right: Smaller RPM meter
        self.rpm_box = BoxLayout(orientation='vertical', size_hint=(.3, 1))
        self.rpm_meter = CircularMeter(max_val=8000, step=1000, unit='RPM', scale=0.75)
        self.rpm_box.add_widget(self.rpm_meter)
        self.layout.add_widget(self.rpm_box)

        self.content_layout.add_widget(self.layout)

        # For updating metrics every 5 seconds
        Clock.schedule_interval(self.update_value_box, 5)
        # For updating meters every 0.1 seconds with random data
        Clock.schedule_interval(self.update_random_stats, 0.1)

        # Bind window resize for radius adjustment
        Window.bind(on_resize=self.on_window_resize)

    def update_random_stats(self, dt):
        self.speedometer.update_value(random.randint(0, 200))
        self.rpm_meter.update_value(random.randint(0, 8000))
        self.fuel_bar.update_value(random.randint(0, 100))
        self.throttle_bar.update_value(random.randint(0, 100))
        self.brakes_bar.update_value(random.randint(0, 100))

    def update_value_box(self, dt):
        # Update displayed random metrics
        example_metrics = {
            "Oil Temp": f"{random.randint(70, 120)} C",
            "Battery V": f"{random.uniform(12, 14):.1f} V",
            "Coolant Temp": f"{random.randint(80, 110)} C",
            "Fuel Level": f"{random.randint(0, 100)}%",
            "Engine Load": f"{random.randint(0, 100)}%"
        }
        self.value_box.clear_widgets()
        for k, v in example_metrics.items():
            lbl = Label(text=f"{k}: {v}", size_hint_y=None, height=dp(20), color=(0, 0, 0, 1))
            self.value_box.add_widget(lbl)

    def on_window_resize(self, instance, width, height):
        # Adjust speedometer and rpm radius based on width
        new_radius_speed = dp(120) if width >= 800 else dp(90)
        new_radius_rpm = dp(90) if width >= 800 else dp(70)
        self.speedometer.radius = new_radius_speed
        self.rpm_meter.radius = new_radius_rpm

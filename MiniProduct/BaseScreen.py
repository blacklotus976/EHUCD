from kivy.uix.screenmanager import Screen
from kivy.uix.button import Button
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.gridlayout import GridLayout
from kivy.uix.image import Image  # Import Image to set wallpaper
from kivy.graphics import Color, Rectangle  # To handle background color if no image
from kivy.uix.widget import Widget
from globalData import GlobalData

class BaseScreen(Screen):
    "C:/Users/james/Downloads/461875017_810600284341392_5726606946765077784_n (1).jpg"
    def __init__(self, wallpaper_path="C:/Users/james/Downloads/557ab678-82af-43df-8310-166dfa032f78.jpg", **kwargs):
        super(BaseScreen, self).__init__(**kwargs)

        # Main layout for the screen
        self.main_layout = BoxLayout(orientation='vertical')
        self.content_layout = BoxLayout(orientation='vertical', size_hint=(1, 0.7), padding=[20, 20, 20, 20])

        # Check if wallpaper path is provided, else use default background
        if wallpaper_path:
            self.set_wallpaper(wallpaper_path)
        else:
            self.set_default_background()

        # Footer layout for navigation buttons (at the top)
        footer_layout = GridLayout(cols=6, size_hint_y=0.2)

        # Button style adjustments for a retro radio look
        button_style = {
            'background_color': (0.2, 0.2, 0.2, 1),  # Dark background for buttons
            'color': (1, 1, 1, 1),  # White text color
            'font_size': 22,  # Slightly smaller font size for the retro feel
            'size_hint': (0.2, None),
            'height': '40dp'
        }

        # Create buttons
        self.wagen_button = Button(text='WagenStat', **button_style)
        self.musik_button = Button(text='Musik', **button_style)

        # Add home button first
        footer_layout.add_widget(self.wagen_button)
        footer_layout.add_widget(self.musik_button)

        # Add content and footer to the main layout
        self.main_layout.add_widget(footer_layout)
        self.main_layout.add_widget(self.content_layout)
        self.add_widget(self.main_layout)

        # Bind button events
        self.wagen_button.bind(on_press=self.go_wagen)
        self.musik_button.bind(on_press=self.go_musik)

    def set_wallpaper(self, wallpaper_path):
        """Sets the wallpaper from the specified image file path."""
        try:
            # Create an Image widget to use as the wallpaper
            wallpaper = Image(source=wallpaper_path, allow_stretch=True, keep_ratio=False)
            # Set the image as the background of the screen
            self.add_widget(wallpaper, index=0)  # Add to the bottom layer (index=0)
        except Exception as e:
            print(f"Error loading wallpaper: {e}")
            self.set_default_background()  # Fallback to default background if loading fails

    def set_default_background(self):
        """Sets a default black background if no image is provided."""
        with self.canvas.before:
            Color(0.2, 0.2, 0.2, 1)  # Dark black-like color
            self.rect = Rectangle(size=self.size, pos=self.pos)
            self.bind(size=self._update_rect, pos=self._update_rect)

    def _update_rect(self, instance, value):
        """Updates the size and position of the background rectangle."""
        self.rect.pos = instance.pos
        self.rect.size = instance.size

    def go_wagen(self, instance):
        return

    def go_musik(self, instance):
        return

    def update_song_info(self):
        if GlobalData.is_song_playing:
            self.song_info_msg.text = f"Now Playing: {GlobalData.current_song} by {GlobalData.current_artist}"
        else:
            self.song_info_msg.text = "No song currently playing"
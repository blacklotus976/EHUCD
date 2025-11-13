from kivy.config import Config
Config.set('input', 'wm_touch', 'mouse,multitouch_on_demand')

from kivy.app import App
from kivy.uix.screenmanager import ScreenManager
from MiniProduct.CarScreen import CarScreen


class CarDashboard(App):
    def build(self):
        sm = ScreenManager()
        sm.add_widget(CarScreen(name='Wagen'))
        return sm


if __name__ == '__main__':
    CarDashboard().run()

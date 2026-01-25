from PyQt6.QtCore import QObject, pyqtProperty as Property, pyqtSignal as Signal, pyqtSlot as Slot, QVariant


class WardrobeBox:
    def __init__(self, id=1):
        self.id = id
        self.width = 600
        self.height = 1800
        self.depth = 600
        self.frame_color = "Grey"  # Default matching your screenshot
        self.door_color = "White"
        self.has_knob = True
        self.door_side = "Left"


class WardrobeManager(QObject):
    dataChanged = Signal()

    def __init__(self):
        super().__init__()
        self._current_wardrobe = WardrobeBox()

        # Color mapping to handle hex values for the Canvas
        self._color_map = {
            "Oak": "#d4a373",
            "White": "#ffffff",
            "Grey": "#7f8c8d",
            "Black": "#2c3e50",
            "Anthracite": "#2f3640"
        }

    # --- PROPERTIES FOR QML ---

    @Property(str, notify=dataChanged)
    def frameColor(self):
        name = self._current_wardrobe.frame_color
        return self._color_map.get(name, name)

    @Property(str, notify=dataChanged)
    def doorColor(self):
        name = self._current_wardrobe.door_color
        return self._color_map.get(name, name)

    @Property(bool, notify=dataChanged)
    def hasKnob(self):
        return self._current_wardrobe.has_knob

    # --- UPDATED SLOT ---
    @Slot(str, str)
    def update_setting(self, key, value):
        w = self._current_wardrobe
        if key == "door_color":
            w.door_color = value
        elif key == "frame_color":
            w.frame_color = value
        elif key == "door_side":
            w.door_side = value
        elif key == "frame_mat":
            w.material = value
        elif key == "knob":
            w.has_knob = (value == "Yes")

        # One signal to rule them all
        self.dataChanged.emit()

    @Slot(result=QVariant)
    def get_full_config(self):
        """Returns the dictionary with all parameters for the canvas"""
        w = self._current_wardrobe
        return {
            "w": w.width,
            "h": w.height,
            "d": w.depth,
            "frameColor": self.frameColor,  # Uses the hex-mapped value
            "doorColor": self.doorColor,
            "doorSide": w.door_side,
            "hasKnob": w.has_knob
        }
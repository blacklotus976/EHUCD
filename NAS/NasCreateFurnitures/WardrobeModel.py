from PyQt6.QtCore import QObject, pyqtProperty as Property, pyqtSignal as Signal, pyqtSlot as Slot, QVariant


class WardrobeBox:
    def __init__(self, id_num):
        self.id = id_num
        self.width = 600.0
        self.height = 1800.0
        self.depth = 600.0
        self.frame_color = "Grey"
        self.door_color = "White"
        self.door_side = "Left"
        self.has_knob = True
        self.bind_to = -1  # <--- New: -1 means None/Standalone


from PyQt6.QtCore import QObject, pyqtProperty as Property, pyqtSignal as Signal, pyqtSlot as Slot, QVariant


class WardrobeBox:
    def __init__(self, id_num):
        self.id = id_num
        self.width = 600
        self.height = 1800
        self.depth = 600
        self.frame_color = "Grey"
        self.door_color = "White"
        self.door_side = "Left"
        self.has_knob = True
        self.bind_to = -1


class WardrobeManager(QObject):
    dataChanged = Signal()
    tabCountChanged = Signal()  # <--- Add this line if it's missing!
    activeIndexChanged = Signal()

    def __init__(self):
        super().__init__()
        # Initialize with one default box
        self._boxes = [WardrobeBox(1)]
        self._active_idx = 0
        self._open_states = {0: False}  # Track open/closed per index
        self._boxes[0].door_side = "Left"  # Don't let it be "None"!

        self._color_map = {
            "Oak": "#d4a373", "White": "#ffffff", "Grey": "#7f8c8d",
            "Black": "#2c3e50", "Anthracite": "#2f3640"
        }

    @Slot(int, result=bool)
    def is_door_open(self, index):
        return self._open_states.get(index, False)

    @Slot(int)
    def toggle_door(self, index):
        if index in self._open_states:
            # Flip the boolean
            self._open_states[index] = not self._open_states[index]
            print(f"Python: Box {index} is now {'Open' if self._open_states[index] else 'Closed'}")
            self.dataChanged.emit()  # This triggers the 3D update
    @Property(int, notify=dataChanged)
    def activeIndex(self):
        return self._active_idx

    @Property(int, notify=dataChanged)
    def tabCount(self):
        return len(self._boxes)

    @Slot(int)
    def setActiveIndex(self, index):
        if 0 <= index < len(self._boxes):
            self._active_idx = index
            self.dataChanged.emit()

    @Slot()
    def addBox(self):
        new_id = len(self._boxes)
        # Ensure new boxes start with a door visible!
        new_box = WardrobeBox(new_id)
        new_box.door_side = "Left"
        self._boxes.append(new_box)
        self._open_states[new_id] = False
        self.tabCountChanged.emit()  # Ensure QML knows to add the 3D model
        self.dataChanged.emit()

    @Slot(int)
    def removeBox(self, index):
        if len(self._boxes) > 1:
            # 1. Identify if anyone was bound to the box being deleted
            for box in self._boxes:
                if box.bind_to == index:
                    box.bind_to = -1  # Default back to standalone

                # 2. Shift indices for boxes bound to indices higher than 'index'
                elif box.bind_to > index:
                    box.bind_to -= 1

            self._boxes.pop(index)
            self._active_idx = min(self._active_idx, len(self._boxes) - 1)
            self.dataChanged.emit()

    # --- PROPERTIES FOR ACTIVE BOX ---
    @Property(str, notify=dataChanged)
    def frameColor(self):
        name = self._boxes[self._active_idx].frame_color
        return self._color_map.get(name, name)

    @Property(str, notify=dataChanged)
    def doorColor(self):
        name = self._boxes[self._active_idx].door_color
        return self._color_map.get(name, name)

    # --- UPDATED SLOT TO TARGET ACTIVE BOX ---
    @Slot(str, str)
    def update_setting(self, key, value):
        w = self._boxes[self._active_idx]
        current_val = str(getattr(w, key)) if hasattr(w, key) else ""
        if current_val == value:
            return
        if key == "door_side":
            w.door_side = value  # Value can now be "Left", "Right", or "None"
        elif key == "door_color":
            w.door_color = value
        elif key == "frame_color":
            w.frame_color = value
        elif key == "door_side":
            w.door_side = value
        elif key == "width":
            w.width = float(value)
        elif key == "height":
            w.height = float(value)
        elif key == "depth":
            w.depth = float(value)
        elif key == "knob":
            w.has_knob = (value == "Yes")
        elif key == "bind_to":
            try:
                # 1. Parse the value
                target_idx = -1
                if isinstance(value, str) and "Box" in value:
                    target_idx = int(value.replace("Box ", "")) - 1
                else:
                    target_idx = int(value)

                # 2. Prevent a box from binding to itself (Safety check)
                if target_idx == self._active_idx:
                    target_idx = -1

                # 3. Apply the change
                w.bind_to = target_idx

                # 4. INSTANT UPDATE: Tell QML the data structure has changed.
                # This will trigger the 'visible' and 'width' properties in your QML Tabs to re-evaluate.
                self.dataChanged.emit()

                # 5. OPTIONAL: If your 3D view relies on an active index signal
                self.activeIndexChanged.emit()

            except (ValueError, TypeError):
                w.bind_to = -1
                self.dataChanged.emit()
        self.dataChanged.emit()

    @Slot(int, result=str)
    def get_neighbor_side(self, offset):
        target = self._active_idx + offset
        if 0 <= target < len(self._boxes):
            return self._boxes[target].door_side
        return "None"

    @Slot(int, int)
    def moveBox(self, old_index, new_index):
        """Swaps or moves boxes in the list"""
        if 0 <= new_index < len(self._boxes):
            box = self._boxes.pop(old_index)
            self._boxes.insert(new_index, box)
            self._active_idx = new_index
            self.dataChanged.emit()

    @Slot(result=QVariant)
    def get_full_config(self):
        w = self._boxes[self._active_idx]
        return {
            "w": w.width, "h": w.height, "d": w.depth,
            "frameColor": self.frameColor,
            "doorColor": self.doorColor,
            "doorSide": w.door_side,
            "hasKnob": w.has_knob
        }

    @Slot(result=QVariant)
    def get_all_boxes(self):
        """Returns a list of all box configurations for merged view"""
        return [
            {
                "w": b.width, "h": b.height, "d": b.depth,
                "side": b.door_side, "fCol": self._color_map.get(b.frame_color, "grey"),
                "dCol": self._color_map.get(b.door_color, "white")
            } for b in self._boxes
        ]

    @Slot(result=float)
    def get_total_width(self):
        """Calculates the combined width of all boxes in the set."""
        return sum(b.width for b in self._boxes)

    @Slot(int, result=float)
    def get_box_width(self, index):
        """Returns the width of a specific box index."""
        if 0 <= index < len(self._boxes):
            return self._boxes[index].width
        return 0.0

    @Slot(int, result=QVariant)
    def get_config_at(self, index):
        """Returns the full data for a specific box (used by Repeater3D)."""
        if 0 <= index < len(self._boxes):
            b = self._boxes[index]
            return {
                "w": b.width,
                "h": b.height,
                "d": b.depth,
                "frame_color": self._color_map.get(b.frame_color, b.frame_color),
                "door_color": self._color_map.get(b.door_color, b.door_color),
                "door_side": b.door_side,
                "bind_to": b.bind_to  # <--- Pass this to QML
            }
        return None

    @Slot(result=float)
    def get_max_height(self):
        max_h = 0
        for i, b in enumerate(self._boxes):
            current_y = 0
            # If bound, add the height of the parent
            if b.bind_to != -1 and b.bind_to < len(self._boxes):
                current_y = self._boxes[b.bind_to].height

            total_reach = current_y + b.height
            if total_reach > max_h:
                max_h = total_reach
        return max_h

    @Slot(result=float)
    def get_total_width(self):
        # Only count widths of boxes NOT bound to others (horizontal footprint)
        return sum(b.width for b in self._boxes if b.bind_to == -1)

    @Slot(result=float)
    def get_total_width(self):
        # Only sum boxes that are on the floor (not bound)
        return sum(b.width for b in self._boxes if b.bind_to == -1)

    @Slot(result=float)
    def get_max_height(self):
        # This is trickier: you'd need to find the tallest stack.
        # For now, return the max of any single box or a default.
        if not self._boxes: return 0.0
        return max(b.height for b in self._boxes)

    @Slot(result=float)
    def get_max_depth(self):
        if not self._boxes: return 0.0
        return max(b.depth for b in self._boxes)

    @Slot(int, int, result=bool)
    def is_descendant_of(self, child_idx, parent_idx):
        """Crucial for the Tab Stacking: checks if a box belongs to a specific floor stack"""
        if child_idx < 0 or child_idx >= len(self._boxes): return False

        current = self._boxes[child_idx].bind_to
        # Loop up the chain to see if we eventually hit parent_idx
        safety = 0
        while current != -1 and safety < 10:
            if current == parent_idx:
                return True
            current = self._boxes[current].bind_to
            safety += 1
        return False
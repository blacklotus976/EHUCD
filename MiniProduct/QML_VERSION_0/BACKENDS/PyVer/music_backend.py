# backend_music.py
import os
from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot, pyqtProperty


class MusicBackend(QObject):
    
    # 🔔 emit when folder changes
    musicRootChanged = pyqtSignal(str)

    def __init__(self, music_root):
        super().__init__()
        self.music_root = music_root

    @pyqtProperty(str, notify=musicRootChanged)
    def musicRoot(self):
        return self.music_root

    @musicRoot.setter
    def musicRoot(self, new_root):
        if new_root and new_root != self.music_root:
            new_root = os.path.normpath(new_root)
            print(f"[MusicBackend] Updating music root to: {new_root}")
            self.music_root = new_root
            self.musicRootChanged.emit(new_root)

    @pyqtSlot(result='QVariantList')
    def get_music_folders(self):
        """Return albums and songs in music_root safely."""
        data = []

        # --- Safety guard ---
        if not self.music_root or not os.path.exists(self.music_root):
            print(f"[MusicBackend] ⚠️ Path missing or invalid: {self.music_root}")
            return data

        try:
            for entry in os.scandir(self.music_root):
                if entry.is_dir():
                    folder = {"name": entry.name, "songs": []}
                    for f in os.listdir(entry.path):
                        if f.lower().endswith((".mp3", ".wav", ".ogg")):
                            path = os.path.join(entry.path, f)
                            folder["songs"].append({
                                "title": os.path.splitext(f)[0],
                                "fileUrl": "file:///" + path.replace("\\", "/")
                            })
                    data.append(folder)

            # Include "Alles" group (songs directly in root)
            alles = [
                {
                    "title": os.path.splitext(f)[0],
                    "fileUrl": "file:///" + os.path.join(self.music_root, f).replace("\\", "/")
                }
                for f in os.listdir(self.music_root)
                if f.lower().endswith((".mp3", ".wav", ".ogg"))
            ]
            if alles:
                data.append({"name": "Alles", "songs": alles})

        except Exception as e:
            print(f"[MusicBackend] ❌ Error scanning folder '{self.music_root}': {e}")

        print(f"[MusicBackend] ✅ Loaded {len(data)} folders from {self.music_root}")
        return data



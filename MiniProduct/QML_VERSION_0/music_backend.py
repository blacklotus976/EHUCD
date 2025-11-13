# backend_music.py
import os
from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot


class MusicBackend(QObject):
    def __init__(self, music_root):
        super().__init__()
        self.music_root = music_root

    @pyqtSlot(result='QVariantList')
    def get_music_folders(self):
        """
        Returns a list of folders (albums/playlists) and songs inside each.
        Structure:
        [
          { "name": "Album1", "songs": [
                { "title": "Track1", "fileUrl": "file:///..." },
                { "title": "Track2", "fileUrl": "file:///..." }
            ]
          },
          ...
        ]
        """
        data = []

        # Scan subfolders as albums
        for entry in os.scandir(self.music_root):
            if entry.is_dir():
                folder = {
                    "name": entry.name,
                    "songs": []
                }
                for f in os.listdir(entry.path):
                    if f.lower().endswith((".mp3", ".wav", ".ogg")):
                        path = os.path.join(entry.path, f)
                        folder["songs"].append({
                            "title": os.path.splitext(f)[0],
                            "fileUrl": "file:///" + path.replace("\\", "/")
                        })
                data.append(folder)

        # Include singles directly in the root
        singles = [
            {
                "title": os.path.splitext(f)[0],
                "fileUrl": "file:///" + os.path.join(self.music_root, f).replace("\\", "/")
            }
            for f in os.listdir(self.music_root)
            if f.lower().endswith((".mp3", ".wav", ".ogg"))
        ]
        if singles:
            data.append({"name": "Singles", "songs": singles})
        print(data)
        return data


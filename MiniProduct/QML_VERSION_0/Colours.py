ALL_AVAILABLE_COLORS = {
        "None": "transparent" ,
        "Black": "#000000" ,
        "Blue": "#0000ff" ,
        "Red": "#ff0000" ,
        "Orange": "#ffa500" ,
        "Yellow": "#ffff00" ,
        "Green": "#00ff00" ,
        "Dark Blue": "#000080" ,
        "Pink": "#ff69b4" ,
        "White": "#ffffff" ,
        "Gray": "#808080" ,
        "Nero": "#2a2a2a"
}

def find_colours_by_tag(target_value):
    return [key for key, value in ALL_AVAILABLE_COLORS.items() if value == target_value]



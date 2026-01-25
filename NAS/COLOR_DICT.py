COLOUR_DICT = {
    'cloud':"#f0f0f0",
    'white':'white',
    'midnight_blue':"#2c3e50",
    'emerald_green': '#27ae60',
    'transparent':'transparent',
    'black':'#000000',
    'belize_hole':"#34495e",
    'platinum_grey': '#eee',
    'red':"#ff0000",
}



import inspect
import os

# TODO: SOS!!! CHANGE TO RETURN DEFAULT BEFORE COMPILATION OF APP, I'M LEAVING IT TO RAISE TO CATCH EASIER COLOUR BUGS
def get_colour(x: str) -> str:
    try:
        return COLOUR_DICT[x]
    except KeyError:
        # Get the previous frame in the stack (the person who called this function)
        caller = inspect.stack()[1]
        file_path = caller.filename
        file_name = os.path.basename(file_path)  # Just the file name, not the whole C:\... path
        line_num = caller.lineno

        error_msg = f"\n[COLOUR ERROR]\n" \
                    f"Requested: '{x}'\n" \
                    f"Location:  File '{file_name}', Line {line_num}\n" \
                    f"Path:      {file_path}\n"

        exit(error_msg)

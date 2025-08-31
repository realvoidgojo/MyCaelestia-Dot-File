function fish_greeting
    # Get a random PNG image from the anime fanart directory
    set anime_dir ~/Pictures/anime_fanart
    set images $anime_dir/*.png
    
    # Check if any PNG files exist
    if test (count $images) -gt 0
        # Select a random image
        set random_image $images[(random 1 (count $images))]
        
        # Display the image using chafa with terminal-friendly settings
        chafa --size=60x10 --colors=256 "$random_image"
    else
        # Fallback to original ASCII art if no images found
        echo -ne '\x1b[38;5;16m'  # Set colour to primary
        echo '     ______           __          __  _       '
        echo '    / ____/___ ____  / /__  _____/ /_(_)___ _ '
        echo '   / /   / __ `/ _ \/ / _ \/ ___/ __/ / __ `/ '
        echo '  / /___/ /_/ /  __/ /  __(__  ) /_/ / /_/ /  '
        echo '  \____/\__,_/\___/_/\___/____/\__/_/\__,_/   '
        set_color normal
    end
    
    fastfetch --key-padding-left 5
end

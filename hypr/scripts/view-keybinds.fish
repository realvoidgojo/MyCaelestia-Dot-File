#!/usr/bin/env fish

set -l config_file ~/.config/hypr/hyprland/keybinds.conf
set -l title "Caelestia Keybindings"
set -l temp_config (mktemp)

# Ensure temp file is cleaned up on exit
trap "rm -f $temp_config" EXIT

while true
    # Create a temporary, parsable version of the keybinds file
    # Format: line_number<SEP>indent<SEP>bind_type<SEP>modifiers<SEP>key<SEP>dispatcher<SEP>command<SEP>description<SEP>is_core
    set -l sep "@@@"
    echo -n > $temp_config # Clear temp file

    set -l num 0
    while read -l content
        set num (math $num + 1)

        # Skip empty lines and pure comments
        set -l trimmed_content (string trim "$content")
        if test -z "$trimmed_content"
            continue
        end
        if string match -q -r '^\s*#' "$content"
            continue
        end

        # Skip non-binding lines (exec, submap, variable assignments, etc.)
        if string match -q -r '^\s*(exec|submap|\$[a-zA-Z_][a-zA-Z0-9_]*\s*=)' "$content"
            continue
        end

        # Only process lines that start with actual bind commands
        if not string match -q -r '^\s*bind[elmri]*\s*=' "$content"
            continue
        end

        # Extract comment/description part - MUST have a description to be shown
        set -l comment_part ""
        set -l description ""
        if string match -q -- '*#*' "$content"
            set -l content_parts (string split -m 1 '#' "$content")
            set comment_part (string trim "$content_parts[2]")
            set description (string trim "$comment_part")
        end
        
        # Skip entries without descriptions - this prevents empty entries
        if test -z "$description"
            continue
        end
        
        set -l is_core "false"
        if string match -q -- '*core*' "$comment_part"
            set is_core "true"
        end

        # Extract the main binding part (before the #)
        set -l main_part (string split -m 1 '#' "$content")[1]
        set -l main_part (string trim "$main_part")
        
        # Parse bind_type = modifiers, key, dispatcher, params
        set -l bind_parts (string split -m 1 '=' "$main_part")
        if test (count $bind_parts) -ne 2
            continue
        end
        
        set -l bind_type (string trim "$bind_parts[1]")
        set -l rest (string trim "$bind_parts[2]")

        # Split the rest by commas - need at least 3 parts (modifiers, key, dispatcher)
        set -l cmd_parts (string split ',' "$rest")
        if test (count $cmd_parts) -lt 3
            continue
        end

        set -l modifiers (string trim "$cmd_parts[1]")
        set -l key (string trim "$cmd_parts[2]")
        set -l dispatcher (string trim "$cmd_parts[3]")
        
        # Everything after the dispatcher is command parameters
        set -l command_params ""
        if test (count $cmd_parts) -gt 3
            set -l params_list $cmd_parts[4..-1]
            for param in $params_list
                if test -n "$command_params"
                    set command_params "$command_params, "(string trim "$param")
                else
                    set command_params (string trim "$param")
                end
            end
        end

        # Strict validation: Must have all required fields and they must be meaningful
        if test -z "$modifiers" -o -z "$key" -o -z "$dispatcher" -o -z "$description"
            continue
        end

        # Skip special/problematic entries that don't represent actual key combinations
        if string match -q "catchall" "$key"
            continue
        end
        
        # Skip entries with empty or placeholder modifiers/keys
        if string match -q -r '^\s*$' "$modifiers"
            continue
        end
        if string match -q -r '^\s*$' "$key"
            continue
        end

        # Additional validation for bind_type
        if not string match -q -r '^bind[elmri]*$' "$bind_type"
            continue
        end

        echo "$num$sep$indent$sep$bind_type$sep$modifiers$sep$key$sep$dispatcher$sep$command_params$sep$description$sep$is_core" >> $temp_config
    end < $config_file

    # Read the parsed data for YAD with additional validation
    set yad_data (cat $temp_config | awk -F "$sep" '
    {
        # Additional validation in AWK - only process lines with all required fields
        if (NF >= 9 && $4 != "" && $5 != "" && $6 != "" && $8 != "") {
            icon="input-keyboard";
            if ($9 == "true") { icon="security-high" };
            command_display = $6;
            if ($7 != "") { command_display = $6 " " $7 };
            print icon"\n"$4"\n"$5"\n"command_display"\n"$8"\n"$1
        }
    }')

    # Only proceed if we have actual data to display
    if test -z "$yad_data"
        yad --error --text="No valid keybindings found in the configuration file."
        break
    end

    # Display the list with yad. Capture both output and exit code.
    set -l yad_output (
        yad --list --no-markup --wrap-width=30 --ellipsize=END \
            --title=$title \
            --width=1200 --height=800 \
            --button="Add:1" --button="Edit:2" --button="Close:0" \
            --column="Icon:IMG" --column="Modifiers" --column="Key" --column="Command" --column="Description" --column="line:HD" \
            --search-column=4 \
            --print-column=6 \
            $yad_data
    )
    set -l exit_code $status
    set -l selected_line (string trim -c '|\n' -- "$yad_output")

    switch $exit_code
        case 1 # Add
            set form_output (
                yad --form --title="Add Keybind" --width=500 \
                    --field="Type:CB" "bind!bindl!bindr!binde!bindm!bindi!bindin" \
                    --field="Modifiers" "Super" \
                    --field="Key" "" \
                    --field="Dispatcher" "exec" \
                    --field="Command" "" \
                    --field="Description" ""
            )
            if test $status -eq 0
                set -l parts (string split -- "|" "$form_output")
                set -l new_modifiers (string trim "$parts[2]")
                set -l new_key (string trim "$parts[3]")
                set -l new_description (string trim "$parts[6]")

                # Validate required fields
                if test -z "$new_modifiers" -o -z "$new_key" -o -z "$new_description"
                    yad --error --text="All fields (Modifiers, Key, Description) are required."
                    continue
                end

                # Conflict detection
                set -l conflict_found false
                while read -l line
                    set -l existing_parts (string split -- "$sep" "$line")
                    if test (string trim "$existing_parts[4]") = "$new_modifiers" -a (string trim "$existing_parts[5]") = "$new_key"
                        set conflict_found true
                        set -l conflict_line $existing_parts[1]
                        break
                    end
                end < $temp_config

                if $conflict_found
                    yad --error --text="Cannot add keybinding.\nThe combination '$new_modifiers + $new_key' is already in use on line $conflict_line."
                    continue
                end

                set -l command_part ""
                if test -n "$parts[4]"
                    set command_part ", $parts[4]"
                    if test -n "$parts[5]"
                        set command_part "$command_part, $parts[5]"
                    end
                end
                
                set -l new_line "    $parts[1] = $parts[2], $parts[3]$command_part # $parts[6]"
                printf "\n%s" "$new_line" >> $config_file
                hyprctl reload
            end
        case 2 # Edit
            if test -z "$selected_line"
                yad --error --text="Please select a keybinding to edit first."
                continue
            end
            set -l line_data (grep "^$selected_line$sep" $temp_config)
            set -l parts (string split -- "$sep" "$line_data")

            set form_output (
                yad --form --title="Edit Keybind" --width=500 \
                    --field="Type:CB" "$parts[3]!bind!bindl!bindr!binde!bindm!bindi!bindin" \
                    --field="Modifiers:CBE" "$parts[4]" \
                    --field="Key:CBE" "$parts[5]" \
                    --field="Dispatcher:CBE" "$parts[6]" \
                    --field="Command:CBE" "$parts[7]" \
                    --field="Description" "$parts[8]"
            )
            if test $status -eq 0
                set -l new_parts (string split -- "|" "$form_output")
                set -l new_modifiers (string trim "$new_parts[2]")
                set -l new_key (string trim "$new_parts[3]")
                set -l new_description (string trim "$new_parts[6]")

                # Validate required fields
                if test -z "$new_modifiers" -o -z "$new_key" -o -z "$new_description"
                    yad --error --text="All fields (Modifiers, Key, Description) are required."
                    continue
                end

                # Conflict detection
                set -l conflict_found false
                while read -l line
                    set -l existing_parts (string split -- "$sep" "$line")
                    set -l line_num $existing_parts[1]
                    # Skip the line we are currently editing
                    if test "$line_num" = "$selected_line"; continue; end

                    if test (string trim "$existing_parts[4]") = "$new_modifiers" -a (string trim "$existing_parts[5]") = "$new_key"
                        set conflict_found true
                        set -l conflict_line $line_num
                        break
                    end
                end < $temp_config

                if $conflict_found
                    yad --error --text="Cannot assign keybinding.\nThe combination '$new_modifiers + $new_key' is already in use on line $conflict_line."
                    continue
                end

                set -l original_indent "$parts[2]"
                set -l command_part ""
                if test -n "$new_parts[4]"
                    set command_part ", $new_parts[4]"
                    if test -n "$new_parts[5]"
                        set command_part "$command_part, $new_parts[5]"
                    end
                end

                set -l new_line "$original_indent$new_parts[1] = $new_parts[2], $new_parts[3]$command_part # $new_parts[6]"
                sed -i "$selected_line""s|.*|$new_line|" $config_file
                hyprctl reload
            end
        case 0 # Close button
            break
        case -1 # Closed with Esc or window manager
            break
        case '*' # Any other exit code, including killactive
            break
    end
end
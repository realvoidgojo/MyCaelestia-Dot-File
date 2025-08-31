if status is-interactive
    # Starship custom prompt
    starship init fish | source

    # Custom colours
    cat ~/.local/state/caelestia/sequences.txt 2> /dev/null

    # For jumping between prompts in foot terminal
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
end

# Battery conservation mode function
function setcharging
    set -l value $argv[1]
    if test -z "$value"
        set value 1
    end
    echo $value | sudo tee /sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/VPC2004:00/conservation_mode
end

# Aliases for battery conservation mode
alias sc-on='setcharging 1'
alias sc-off='setcharging 0'

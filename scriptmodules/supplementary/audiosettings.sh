#!/usr/bin/env bash

# This file is part of The RetroPie Project
#
# The RetroPie Project is the legal property of its developers, whose names are
# too numerous to list here. Please refer to the COPYRIGHT.md file distributed with this source.
#
# See the LICENSE.md file at the top-level directory of this distribution and
# at https://raw.githubusercontent.com/RetroPie/RetroPie-Setup/master/LICENSE.md
#

rp_module_id="audiosettings"
rp_module_desc="Configure audio settings"
rp_module_section="config"
rp_module_flags="!x86 !mali"

function depends_audiosettings() {
    if [[ "$md_mode" == "install" ]]; then
        getDepends alsa-utils
    fi
}

function get_dialog_volume_audiosettings() {
    local step=5

    local volume=$(($1 / $step))
    local threshold_yellow=$((50 / $step))
    local threshold_red=$((90 / $step))

    local volume_string="   $(printf "%03d" $1)%\n\n"

    local i=$((100 / $step))
    while [[ $i -gt 0 ]]; do
        if [[ $i -gt $volume ]]; then
            volume_string+="   |  |\n"
        else
            if [[ $i -gt $threshold_red ]]; then
                volume_string+="   |\Zr\Z1  \Zn|\n"
            elif [[ $i -gt $threshold_yellow ]]; then
                volume_string+="   |\Zr\Z3  \Zn|\n"
            else
                volume_string+="   |\Zr\Z2  \Zn|\n"
            fi
        fi
        ((i--))
    done
    echo -en "$volume_string"
}

function gui_volumemixer_audiosettings() {
    while true; do
        local volume_data=$(amixer cget numid=1)
        
        local min_bound=$(echo $volume_data | grep -E -o -e ',min=[^,]+' | grep -E -o -e '[0-9-]+')
        local max_bound=$(echo $volume_data | grep -E -o -e ',max=[^,]+' | grep -E -o -e '[0-9-]+')
        local volume_value=$(echo $volume_data | grep -E -o -e ': values=[0-9+-]+' | grep -E -o -e '[0-9-]+')
        
        local volume_percent=$(((100 * ($volume_value - $min_bound)) / ($max_bound - $min_bound)))
        local volume_up=$(($volume_percent + 1))
        if [[ $volume_up -ge 100 ]]; then
            volume_up=100
        fi
        local volume_dn=$(($volume_percent - 1))
        if [[ $volume_dn -le 0 ]]; then
            volume_dn=0
        fi
        local volume_bar=$(get_dialog_volume_audiosettings "$volume_percent")
        local cmd=(dialog --colors --backtitle "$__backtitle" --infobox "$volume_bar" 24 14)
        local dialog=$("${cmd[@]}" 2>&1 >/dev/tty)
        while read -rsn1 input; do
            case $input in
            $'\x1b')
                # Handle ESC sequence.
                # Flush read. We account for sequences for Fx keys as
                # well. 6 should suffice far more then enough.
                read -rsn1 -t 0.01 escchar
                if [[ "$escchar" == "" ]]; then
                    # ESCAPE key - Exit
                    break 2
                fi
                input+="$escchar"
                read -rsn1 -t 0.01 escchar
                input+="$escchar"
                case $input in
                $'\e[A')
                    # UP ARROW key - Volume up
                    amixer -q cset numid=1 -- $(($volume_up))% >/dev/null
                    alsactl store
                    break
                    ;;
                $'\e[B')
                    # DOWN ARROW - Volume down
                    amixer -q cset numid=1 -- $(($volume_dn))% >/dev/null
                    alsactl store
                    break
                    ;;
                esac
                # Flush "stdin" with 0.001  sec timeout.
                read -rsn5 -t 0.001
                ;;
            "")
                # ENTER key - Exit
                break 2
                ;;
            *)
                # Any other key - Ignore
                ;;
            esac
        done
    done
}

function gui_audiosettings() {
    local cmd=(dialog --backtitle "$__backtitle" --menu "Set audio output." 22 86 16)
    local options=(
        1 "Auto"
        2 "Headphones - 3.5mm jack"
        3 "HDMI"
        4 "Mixer - adjust output volume"
        5 "Mixer - controller-friendly"
        R "Reset to default"
    )
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    if [[ -n "$choice" ]]; then
        case "$choice" in
            1)
                amixer cset numid=3 0
                alsactl store
                printMsgs "dialog" "Set audio output to auto"
                ;;
            2)
                amixer cset numid=3 1
                alsactl store
                printMsgs "dialog" "Set audio output to headphones / 3.5mm jack"
                ;;
            3)
                amixer cset numid=3 2
                alsactl store
                printMsgs "dialog" "Set audio output to HDMI"
                ;;
            4)
                alsamixer >/dev/tty </dev/tty
                alsactl store
                ;;
            5)
                rp_callModule audiosettings gui_volumemixer
                ;;
            R)
                /etc/init.d/alsa-utils reset
                alsactl store
                printMsgs "dialog" "Audio settings reset to defaults"
                ;;
        esac
    fi
}

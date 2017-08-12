#! /bin/sh

PANEL_WM=panel_bottom
PANEL_FIFO=/tmp/panel_bottom_fifo

if xdo id -a "$PANEL_WM" > /dev/null ; then
    printf "%s\n" "The panel is already running." >&2
    exit 1
fi

trap 'trap - TERM; kill 0' INT TERM QUIT EXIT

[ -e "$PANEL_FIFO" ] && rm "$PANEL_FIFO"
mkfifo "$PANEL_FIFO"

source $(dirname $0)/config_bar

music() {
    local icon=$(pIcon ${GREEN} ${CSOUND})
    local stat="$(mpc status | grep \# | awk '{print $1}')"
    local artist=$(mpc -f %artist% current)
    local musicname=$(mpc -f %title% current)
    local cmd=""

    if [ "${stat}" ] && [ "${stat}" = "[playing]" ] ; then
        cmd=" Playing $(sepr) ${artist} - ${musicname}"
    elif [ "${stat}" ] && [ "${stat}" = "[paused]" ] ; then
        cmd=" Paused $(sepr) ${artist} - ${musicname}"
    else
        cmd=" No Sound"
    fi

    echo "${icon} $(pText ${WHITE} "${cmd}") $(sepr)"
}

volume() {
    local icon=$(pIcon ${GREEN} ${CVOLUME})
    local cmd="$(~/.local/bin/getvolume)"
    [[ -z ${volume%?} ]] && volume='100%'
    local clr=$(pText ${FG} "${cmd}")
    echo "${icon} ${clr}"
}

net() {
    local _GETIWL=$(/sbin/iwgetid -r)
    local _GETETH=$(ip a | grep "state UP" | awk '{ORS=""}{print $2}' | cut -d ':' -f 1)
    local _status=${_GETIWL:-$_GETETH}
    local _status2="${_status:-Down}"
    local icon="$(pIcon ${GREEN} ${CWIFI})"
    local cmd=$(pText ${WHITE} " ${_status2} ")

    echo "${cmd}${icon} $(pText ${WHITE} " ")"
} 

wifi_str() {
    local _cmd=$(/sbin/iwconfig 2>/dev/null | grep "Link Quality" | cut -d "=" -f 2 | awk '{print $1}')
    local _percent=$(cat /proc/net/wireless | awk "NR==3 {print \$3 \" %\"}" | sed "s/\. //g")
    echo "$(sepl) ${_percent}"
}

cpu() {
    local icon=$(pIcon ${GREEN} ${CCPU})
    local cmd="CPU:"
    local clr=$(pText ${WHITE} "${cmd}")
    echo "${icon}${clr}"
}

ram() {
    local icon=$(pIcon ${GREEN} ${CRAM})
    local cmd=$(free -m | grep Mem | awk '{print $3}')
    cmd+=" Mb"
    local clr=$(pText ${WHITE} "${cmd}")
    echo "${icon} ${clr}"
}

ws() {
    local hidden="$(i3-msg -t get_workspaces | jq -Mrc '.[] | {visible,name} | if .visible == false then {name} else {} end | .[]' | tr "\n" "|" | sed 's/|$//g' | sed 's/|/ | /g')"
    if [ ! -z "${hidden}" ]; then
        local hiddenEnd="$(pIcon ${FG} "${hidden}")"
        echo "$(sepl) ${hiddenEnd} $(sepr)"
    fi
}

up() {
    local cmd=$(uptime -p)
    local uptime=$(pText ${WHITE} "${cmd}")
    echo "${uptime}"
}

mail() {
    local icon=$(pIcon ${GREEN} ${CMAIL})
    local declare maildirs=("/home/mello/.mail/triathlon/Inbox/new" \
        "/home/mello/.mail/university/Inbox/new" \
        "/home/mello/.mail/education/Inbox/new" \
        "/home/mello/.mail/m3llo/Inbox/new")
    local declare mailname=("Triathlon: " "University: " "Education: " "m3llo: ")
    local declare count
    for index in ${!maildirs[*]}
    do
        if [[ ! -n $(ls "${maildirs[$index]}") ]]; then
            count[$index]=""
        else
            count[$index]="${mailname[$index]}$(ls -1 "${maildirs[$index]}" | wc -l) |"
        fi
    done
    echo "$(sepl) $(echo ${cmd} ${count[0]} ${count[1]} ${count[2]} ${count[3]} | sed s'/|$//') ${icon} "
}

{
    while :; do
        echo "A$(sep l)$(ws)$(sep r)"
        echo "W $(music) $(volume) "
	    sleep 0.1 || break
    done > "$PANEL_FIFO" &

    while :; do
        echo "R $(up) $(sep r) $(mail) $(wifi_str) $(net)"
        sleep 30
    done > "$PANEL_FIFO" &
}

{
    while read -r line ; do
        cmd=( $line )
        case "${cmd[0]}" in
            W*)
                sysL="${line#?}"
                ;;
            A*)
                wm="${line#?}"
                ;;
            R*)
                sysR="${line#?}"
                ;;
            reload)
                exit
                ;;
            quit_panel)
                exit
                ;;
        esac
        printf "%s\n" "%{l}${sysL}%{c}${wm}%{r}${sysR}"
    done
} < "$PANEL_FIFO" | lemonbar \
    -g x${HEIGHT} -u 2 -B ${BG} -F ${FG} -f "${FONT}" -o -4 -f "${FONT_ICON}" -o 2 -b | sh &

wid=$(xdo id -a "$PANEL_WM")
tries_left=20

while [ -z "$wid" -a "$tries_left" -gt 0 ] ; do
    sleep 0.05
    wid=$(xdo id -a "$PANEL_WM")
    tries_left=$((tries_left - 1))
done

[ -n "$wid" ] && xdo above -t "$(xdo id -N I3Bottom -n root | sort | head -n 1)" "$wid"

wait

#! /bin/sh

PANEL_WM=panel_top
PANEL_FIFO=/tmp/panel_top_fifo

if xdo id -a "$PANEL_WM" > /dev/null ; then
    printf "%s\n" "The panel is already running." >&2
    exit 1
fi

trap 'trap - TERM; kill 0' INT TERM QUIT EXIT

[ -e "$PANEL_FIFO" ] && rm "$PANEL_FIFO"
mkfifo "$PANEL_FIFO"

source $(dirname $0)/config_bar

getName() {
    local icon=$(pIcon ${CYAN} ${ARCH})
    local nameCmd="$USER is on $(uname -n)"
    local name=$(pText ${WHITE} "${nameCmd}")
    echo " ${icon} ${name} ${separator}$(sepr)"
}

getMyIp() {
    local ipCmd="$(curl -s https://ifcfg.me/)"
    local ipText=$(pText ${WHITE} "${ipCmd}")
    echo "${ipText} $(sepr)"
}

getDay() {
    local dateText=" $(date '+%A %d %b')" 
    local date=$(pText ${WHITE} "${dateText}")
    echo "$(sepl) ${date}"
}

clock() {
    local icon=$(pIcon ${GREEN} ${CTIME})
    local timeText=$(date +%H:%M:%S)
    local time=$(pText ${FG} "${timeText} ")
    echo "${time}${icon} $(pText ${WHITE} " ")"
}

mail() {
    local declare maildirs=("/home/mello/.mail/triathlon/Inbox/new" \
        "/home/mello/.mail/university/Inbox/new" \
        "/home/mello/.mail/education/Inbox/new" \
        "/home/mello/.mail/m3llo/Inbox/new")
    local count=0
    for index in ${!maildirs[*]}
    do
        if [[ -n $(ls "${maildirs[$index]}") ]]; then
            count=$(($count + $(ls -1 "${maildirs[$index]}" | wc -l)))
        fi
    done
    local cmd=$(pAction ${GREEN} ${BG} "i3 'exec urxvt -e mutt'" "${CMAIL}")
    local text=$(pAction ${WHITE} ${BG} "i3 'exec urxvt -e mutt'" "${count}")
    echo "$(sepl) ${text} ${cmd}"
}

energy() {
    local ac=/sys/class/power_supply/ADP1/online
    local bat=/sys/class/power_supply/BAT1/present
    local icon=""
    local batCap=""
    if [[ -e $bat ]] && [[ $(cat $ac) -lt 1 ]]; then
        batCap="$(cat ${bat%/*}/capacity)"
        [ $batCap -gt 90 ] && icon=$(pIconCustom ${GREEN} ${BAT100} 4)
        [ $batCap -gt 70 ] && [ $batCap -lt 90 ] && icon=$(pIconCustom ${GREEN} ${BAT70} 4)
        [ $batCap -gt 50 ] && [ $batCap -lt 70 ] && icon=$(pIconCustom ${GREEN} ${BAT50} 4)
        [ $batCap -gt 30 ] && [ $batCap -lt 50 ] && icon=$(pIconCustom ${GREEN} ${BAT30} 4)
        [ $batCap -gt 15 ] && [ $batCap -lt 30 ] && icon=$(pIconCustom ${GREEN} ${BAT15} 4)
        [ $batCap -lt 7 ] && icon=$(pIconCustom ${GREEN} ${BAT7} 4)
    elif [[ -n $(cat $ac) ]]; then
        batCap="$(cat ${bat%/*}/capacity)"
        icon=$(pIconCustom ${GREEN} ${CAC} 3)
    else
        batCap="wttf"
    fi
    echo "$(pText ${WHITE} ${batCap}) ${icon}"
}

ws() {
    local visible=$(i3-msg -t get_workspaces | jq -Mrc '.[] | {visible,name} | if .visible == true then {name} else {} end | .[]')
    local visibleText=$(pIconCustom ${RED2} "${visible}" 1)
    echo "$(sepr) ${visibleText} $(sepl)"
}

getWeather() {
    local cmd=$(~/.local/bin/weather)
    echo "$(weather)"
}

{
    while :; do
        echo "A$(ws)"
        echo "R$(input) $(energy) $(mail) $(getDay) $(clock)"
        sleep 1 || break
    done > "$PANEL_FIFO" &


    while :; do
        echo "A$(ws)"
        sleep 0.2 || break
    done > "$PANEL_FIFO" &

    while :; do
        echo "W$(getName) $(getMyIp) $(getWeather)"
        sleep 10 || break
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
                sysC="${line#?}"
                ;;
            R*)
                sysR="${line#?}"
                ;;
        esac
        printf "%s\n" "%{l}${sysL}%{c}${sysC}%{r}${sysR}"
    done
} < "$PANEL_FIFO" | lemonbar \
    -g x${HEIGHT} -u 2 -B ${BG} -F ${FG} -f "${FONT}" -o -8 -f "${FONT_ICON}" -o -2 -f "${FONT_ICON_SMALL}" -o -6 -f "${FONT_ICON_LARGE}" -o 0 | sh &

wid=$(xdo id -a "$PANEL_WM")
tries_left=20

while [ -z "$wid" -a "$tries_left" -gt 0 ] ; do
    sleep 0.05
    wid=$(xdo id -a "$PANEL_WM")
    tries_left=$((tries_left - 1))
done

[ -n "$wid" ] && xdo above -t "$(xdo id -N I3Top -n root | sort | head -n 1)" "$wid"

wait

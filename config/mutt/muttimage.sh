#!/bin/sh

### Determine the size of the terminal
img_size=($(identify $1 | egrep -o -e "([0-9]+x[0-9]+) " -m 1 | sed "s/x/ /g"))
img_width=${img_size[0]}
img_height=${img_size[1]}

term_height=$(($(tput lines)*13))
term_width=$(($(tput cols)*6))

ratioX=$(bc -ql <<< $term_width/$img_width)
ratioY=$(bc -ql <<< $term_height/$img_height)
if [[ $(echo $ratioX \< $ratioY | bc -ql) -eq 0 ]]; then
	ratio=$ratioY
else
	ratio=$ratioX
fi

width=$(printf "%.0f" $(bc -ql <<< $img_width*$ratio))
height=$(printf "%.0f" $(bc -ql <<< $img_height*$ratio))

### Display Image / offset with mutt bar
echo -e "2;3;\n0;1;0;0;$width;$height;0;0;0;0;$1\n4;\n3;" |  /usr/lib/w3m/w3mimgdisplay &

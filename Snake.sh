#!/bin/bash

DELAY=0.2 # Initial ticker delay

TICK=0
UP=1
DOWN=2
LEFT=3
RIGHT=4
QUIT=5

game_loop_enabled=true

AREA_START_X=1
AREA_START_Y=3
AREA_STOP_X=20
AREA_STOP_Y=40

SNAKE_START_X=$(($AREA_STOP_X / 2))
SNAKE_START_Y=$(($AREA_STOP_Y / 2))

SNAKE_POS_X=$SNAKE_START_X
SNAKE_POS_Y=$SNAKE_START_Y

SNAKE_SIZE=3
SNAKE_DIRECTION=$UP

ZEROES=`echo |awk '{printf("%0"'"$SNAKESIZE"'"d\n",$1)}' | sed 's/0/0 /g'`
SNAKE_LAST_POS_X=( $ZEROES )
SNAKE_LAST_POS_Y=( $ZEROES )

WALLCHAR="X"
SNAKECHAR="O"
APPLECHAR="@"

end_game() {
    game_loop_enabled=false
    tput cup $SNAKE_START_X $SNAKE_START_Y
    printf "GAME OVER"
}

generate_new_apple_position() {
    APPLE_POS_X=$[( $RANDOM % ( $[ $AREA_STOP_X - $AREA_START_X ] )) + $AREA_START_X ]
    APPLE_POS_Y=$[( $RANDOM % ( $[ $AREA_STOP_Y - $AREA_START_Y ] )) + $AREA_START_Y ]
}

generate_new_apple() {
    last_snake_part=$(( ${#SNAKE_LAST_POS_X[@]} - 1 ))
    x=0
    generate_new_apple_position
    while [ "$x" -le "$last_snake_part" ]
    do
        if [ "$APPLE_POS_X" = "${SNAKE_LAST_POS_X[$x]}" ] && [ "$APPLE_POS_Y" = "${SNAKE_LAST_POS_Y[$x]}" ]
        then
	    x=0
            generate_new_apple_position
	else
            x=$(( $x + 1 ))
	fi
    done
    tput setf 4
    tput cup $APPLE_POS_X $APPLE_POS_Y
    printf %b "$APPLECHAR"
    tput setf 9
}

snake_add_segment() {
    SNAKE_LAST_POS_X=( ${SNAKE_LAST_POS_X[0]} ${SNAKE_LAST_POS_X[0]} ${SNAKE_LAST_POS_X[0]} ${SNAKE_LAST_POS_X[@]} )
    SNAKE_LAST_POS_Y=( ${SNAKE_LAST_POS_Y[0]} ${SNAKE_LAST_POS_Y[0]} ${SNAKE_LAST_POS_Y[0]} ${SNAKE_LAST_POS_Y[@]} )
}

move_in_dir() {
    case "$SNAKE_DIRECTION" in
        $UP) SNAKE_POS_X=$(( $SNAKE_POS_X - 1 ));;
	$DOWN) SNAKE_POS_X=$(( $SNAKE_POS_X + 1 ));;
	$LEFT) SNAKE_POS_Y=$(( $SNAKE_POS_Y - 1 ));;
	$RIGHT) SNAKE_POS_Y=$(( $SNAKE_POS_Y + 1 ));;
    esac

    if [ "$SNAKE_POS_X" -le "$AREA_START_X" ] || [ "$SNAKE_POS_X" -ge "$AREA_STOP_X" ] ; then
        tput cup $(( $LASTROW + 1 )) 0
	stty echo
	#echo " GAME OVER! You hit a wall!"
        end_game
    elif [ "$SNAKE_POS_Y" -le "$AREA_START_Y" ] || [ "$SNAKE_POS_Y" -ge "$AREA_STOP_Y" ] ; then
        tput cup $(( $LASTROW + 1 )) 0
	end_game
    fi

    # Get ref to last element of array
    last_snake_part=$(( ${#SNAKE_LAST_POS_X[@]} - 1 ))

    x=1
    while [ "$x" -le "$last_snake_part" ];
    do
        if [ "$SNAKE_POS_X" = "${SNAKE_LAST_POS_X[$x]}" ] && [ "$SNAKE_POS_Y" = "${SNAKE_LAST_POS_Y[$x]}" ];
        then
            tput cup $(( $SNAKE_LAST_POS_X + 1 )) 0
            end_game
        fi
        x=$(( $x + 1 ))	
    done

    tput cup ${SNAKE_LAST_POS_X[0]} ${SNAKE_LAST_POS_Y[0]}
    printf " "

    SNAKE_LAST_POS_X=( `echo "${SNAKE_LAST_POS_X[@]}" | cut -d " " -f 2-` $SNAKE_POS_X )
    SNAKE_LAST_POS_Y=( `echo "${SNAKE_LAST_POS_Y[@]}" | cut -d " " -f 2-` $SNAKE_POS_Y )
    tput cup 1 10
    tput cup 2 10
    #echo "SIZE=${#SNAKE_LAST_POS_X[@]}"

    SNAKE_LAST_POS_X=( `echo "${SNAKE_LAST_POS_X[@]}" | cut -d " " -f 2-` $SNAKE_POS_X )
    SNAKE_LAST_POS_Y=( `echo "${SNAKE_LAST_POS_Y[@]}" | cut -d " " -f 2-` $SNAKE_POS_Y )
    #tput cup 1 10
    #echo "LASTPOSX array ${SNAKE_LAST_POS_X[@]} LASTPOSY array ${SNAKE_LAST_POS_Y[@]}"
    #tput cup 2 10
    #echo "SIZE=${#SNAKE_LAST_POS_X[@]}"

    SNAKE_LAST_POS_X[$last_snake_part]=$SNAKE_POS_X
    SNAKE_LAST_POS_Y[$last_snake_part]=$SNAKE_POS_Y

    tput setf 2
    tput cup $SNAKE_POS_X $SNAKE_POS_Y
    printf %b "$SNAKECHAR"
    tput setf 9

    if [ "$APPLE_POS_X" -eq "$SNAKE_POS_X" ] && [ "$APPLE_POS_Y" -eq "$SNAKE_POS_Y" ]
    then
        snake_add_segment
        generate_new_apple
    fi
}

hide_cursor() {
    echo -ne "\033[?25l"
}

show_cursor() {
    echo -ne "\033[?25h"
}

input_reader() {
    trap exit SIGUSR2

    # echo -ne "Start input reader"

    local -u key a='' b='' cmd esc_ch=$'\x1b'

    declare -A commands=(
        [_W]=$UP
        [_S]=$DOWN
        [_A]=$LEFT
        [_D]=$RIGHT
        [_Q]=$QUIT)

    while read -s -n 1 key ; do
        case "$a$b$key" in
            "${esc_ch}["[ACD]) cmd=${commands[$key]} ;; # cursor key
            *${esc_ch}${esc_ch}) cmd=$QUIT ;;           # exit on 2 escapes
            *) cmd=${commands[_$key]:-} ;;              # regular key. If space was pressed $key is empty
        esac
        a=$b   # preserve previous keys
        b=$key
        [ -n "$cmd" ] && echo -n "$cmd"

    done
}

ticker() {
    # on SIGUSR2 this process should exit
    trap exit SIGUSR2

    # echo -ne "Start ticker"

    while true ; do echo -n $TICK; sleep $DELAY; done
}

command_tick() {
    move_in_dir
}

command_dir_up() {
    SNAKE_DIRECTION=$UP
}

command_dir_down() {
    SNAKE_DIRECTION=$DOWN
}

command_dir_left() {
    SNAKE_DIRECTION=$LEFT
}

command_dir_right() {
    SNAKE_DIRECTION=$RIGHT
}

command_quit() {
    printf "QUIT"
}

draw_game_area() {
     # Draw top
    tput setf 6
    tput cup $AREA_START_X $AREA_START_Y
    x=$AREA_START_Y
    while [ "$x" -le "$AREA_STOP_Y" ];
    do
        printf %b "$WALLCHAR"
        x=$(( $x + 1 ));
    done

    # Draw sides
    x=$AREA_START_X
    while [ "$x" -le "$AREA_STOP_X" ];
    do
        tput cup $x $AREA_START_Y; printf %b "$WALLCHAR"
	tput cup $x $AREA_STOP_Y; printf %b "$WALLCHAR"
	x=$(( $x + 1 ));
    done

    # Draw bottom
    tput cup $AREA_STOP_X $AREA_START_Y
    x=$AREA_START_Y
    while [ "$x" -le "$AREA_STOP_Y" ];
    do
        printf %b "$WALLCHAR"
        x=$(( $x + 1 ));
    done
    tput setf 9
}

controller() {
    # SIGUSR1 and SIGUSR2 are ignored
    trap '' SIGUSR1 SIGUSR2

    local cmd commands
    commands[$QUIT]=command_quit
    commands[$UP]=command_dir_up
    commands[$DOWN]=command_dir_down
    commands[$RIGHT]=command_dir_right
    commands[$LEFT]=command_dir_left
    commands[$TICK]=command_tick
    while $game_loop_enabled; do
        read -s -n 1 cmd
        # echo -ne "$cmd"
	${commands[$cmd]}
    done
}

stty_g=`stty -g` # let's save terminal state

clear
hide_cursor
draw_game_area
snake_add_segment
generate_new_apple

(
    ticker &
    input_reader
) | (
    controller
)

show_cursor
stty $stty_g # let's restore terminal state

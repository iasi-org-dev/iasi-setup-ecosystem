echo
echo "ANSI 256-color foreground palette"
echo

for n in {0..255}; do
    printf "\033[38;5;%dm FG%-3d \033[0m" "$n" "$n"

    if (( (n + 1) % 8 == 0 )); then
        echo
    fi
done

echo
echo
echo "ANSI 256-color background palette"
echo

for n in {0..255}; do
    printf "\033[48;5;%dm BG%-3d \033[0m" "$n" "$n"

    if (( (n + 1) % 8 == 0 )); then
        echo
    fi
done

echo
echo "Formats"
echo

printf "${BOLD}BOLD${RESET}  "
printf "${DIM}DIM${RESET}  "
printf "${ITALIC}ITALIC${RESET}  "
printf "${UNDERLINE}UNDERLINE${RESET}  "
printf "${BLINK}BLINK${RESET}  "
printf "${REVERSE}REVERSE${RESET}  "
printf "${STRIKE}STRIKE${RESET}\n"

echo

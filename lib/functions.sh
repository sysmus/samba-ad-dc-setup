whiptail_message()
{
    whiptail \
        --title "$TITLE" \
        --backtitle "$BACKTITLE" \
        --textbox "$1" "$2" "$3"
}

whiptail_input()
{
while [ -z $INPUT ]
do
    INPUT=$(whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
    --inputbox "$1" "$2" "$3" 3>&1 1>&2 2>&3)
done
}

whiptail_password()
{
while [ -z $INPUT ]
do
    INPUT=$(whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
    --passwordbox "$1" "$2" "$3" 3>&1 1>&2 2>&3)
done
}


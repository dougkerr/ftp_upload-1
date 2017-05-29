
# names of the config file and its associated temp file
conf_file=upload.conf
conf_temp=.upload.conf

# standard height and width for message boxes
height=13
width=60

# put up a dialog box to request a configuration value from the user.
#
# usage: confvalbox title message value_name [value [box_height]]
#
confvalbox () {
    local title="$1"
    local msg="$2"
    local name="$3"
    local val="$4"
    local hgt="$5"
    if [ "$val" = "" ]
    then
        val=`get_config $conf_temp $name`
    fi
    if [ "$hgt" = "" ]
    then
        hgt="$height"
    fi

    val=`whiptail --title  "$title" \
        --ok-button Next --cancel-button Previous \
        --inputbox "$msg" $hgt $width "$val" 3>&1 1>&2 2>&3`
    local retval=$?
    case $retval in
        0)
            set_config_value $conf_temp $name "$val"
            return 2
            ;;
        1)
            return 0
            ;;
        *)
            return $retval
    esac
}

# put up the cancel dialog.
# If the first argument is non-empty, offer to save the data entered
#
cancel_dialog() {
    local title="Cancelled"
    local m=""
    if [ "$1" ] # if non-empty, offer to save data
    then
    	m="${m}Do you want to save the data you entered (if any) to be used "
        m="${m}as the default values the next time you run this?"
        m="${m}\n\n                   [ESC will discard]"
        whiptail --title  "$title" --yes-button Save --no-button Discard\
            --yesno "$m" 10 $width
    else
        m="You have cancelled installation."
        whiptail --title  "$title" --msgbox "$m" 8 $width
    fi
}

# create the temporary config file
#
create_conftemp() {
    if [ -r "$conf_file" ]
    then
        cp "$conf_file" "$conf_temp"
        sed -i "/^#>>/d" "$conf_temp"    # remove old comment header
        sed -i '1{x;p;x;}' "$conf_temp"  # insert blank line at top of file
    else
        echo > "$conf_temp"              # insert blank line at top of file
    fi

    # put the new comment header on the temp file.
    # Note: sed needs at least one line in the file to that 
    # Line 1 can be used as an address
    local cmt="#>> Configuration file created by `getluser`@`hostname`\n"
    cmt="${cmt}#>> on `date`\n#>>"
    sed -i "1s|^|$cmt|" "$conf_temp"
}
    
# gather the required config info from the user by displaying a series
# of dialog boxes. Return zero if successful or non-zero if user cancels
#
get_info() {

    create_conftemp

    local esc="\n\n                [Press ESC to cancel]"

    local step=1
    while [ $step -gt 0 ]
    do 
    local m=""
    local title
    case $step in
    1)
        title="Introduction"
        m="${m}This script will configure this machine to receive images "
        m="${m}from a camera and upload them "
        m="${m}to a cloud server running Neighborhood Guard's "
        m="${m}CommunityView software. "
        m="${m}It will ask you for some configuration values, then install and "
        m="${m}configure the software required. "
        m="${m}This script does not use the mouse. "
        m="${m}Move the cursor by using the TAB key or the arrow keys. "

        whiptail --title "$title" --msgbox "$m$esc" 16 $width
        if [ $? = 0 ]  # OK button
        then
            step=`expr $step + 2`
        else    # user cancelled
            step=`expr $step + 255`
        fi
        ;;
    2)
        title="Name This Machine"
        m="${m}The name of this machine will be set to what you enter here. "
        m="${m}The camera "
        m="${m}will use this name to find this machine on the local network. "
        m="${m}The name must be 15 characters or less, and consist only "
        m="${m}of letters, numbers and the dash (\"-\") symbol. "
        m="${m}This machine is currently named '$(hostname)'."
        confvalbox "$title" "$m$esc" um_name `hostname` 15
        step=`expr $step + $?`
        ;;
    3)
        title="Camera's FTP User Name For This Machine"
        m="${m}Enter the user name the camera will use when connecting to "
        m="${m}this machine via FTP to upload images."
        confvalbox "$title" "$m$esc" um_cam_user
        step=`expr $step + $?`
        ;;
    4)
        title="Camera's FTP Password For This Machine"
        m="${m}Enter the password the camera will use when connecting to "
        m="${m}this machine via FTP to upload images."
        confvalbox "$title" "$m$esc" um_cam_pass
        step=`expr $step + $?`
        ;;
    5)
        title="Number of Days to Save Images On This Machine"
        m="${m}Enter the number of days images should be saved on this "
        m="${m}after they have uploaded to the cloud server. This has no "
        m="${m}effect on the number of days the clould server will save "
        m="${m}the images."
        confvalbox "$title" "$m$esc" um_retain_days
        step=`expr $step + $?`
        ;;
    6)
        title="Domain Name of the Cloud Server"
        m="${m}Enter the domain name for the cloud server that this "
        m="${m}machine will upload images to, e.g., yourneighborhood.org."
        confvalbox "$title" "$m$esc" cs_name
        step=`expr $step + $?`
        ;;
    7)
        title="Cloud Server Account Name"
        m="${m}Enter the user name of the cloud server account to which "
        m="${m}this machine will upload images."
        confvalbox "$title" "$m$esc" cs_user
        step=`expr $step + $?`
        ;;
    8)
        title="Cloud Server Account Password"
        m="${m}Enter the password for the cloud server account to which "
        m="${m}this machine will upload images."
        confvalbox "$title" "$m$esc" cs_pass
        step=`expr $step + $?`
        ;;
    9)
        title="Cloud Server FTP Directory"
        m="${m}Enter the name of the directory within the cloud server "
        m="${m}account into which this machine will upload images. This "
        m="${m}is usually a domain name representing the domain portion "
        m="${m}of the URL where the images can be viewed, e.g., "
        m="${m}images.yourneighborhood.org."
        confvalbox "$title" "$m$esc" cs_ftp_dir
        step=`expr $step + $?`
        ;;
    10)
        title="Ready to Install"
        m="${m}Ready in install and configure this machine. "
        m="${m}Select Install to proceed or Prev to go back."
        whiptail --title "$title" --yes-button Install --no-button "Prev" \
            --yesno "$m$esc" $height $width
        case $? in
            0)  # Install button
                mv "$conf_temp" "$conf_file"
                break
                ;;

            1)  # Prev button
                ;;  # will go back to previous step

            *)  # Esc key
                step=`expr $step + 255`
                ;;
        esac
        ;;
    *)
        # this is a cancellation
        local cancel_step=`expr $step - 254`
        local save_offer=""
        if [ $cancel_step -gt 2 ]
        then
            save_offer=1
        fi

        if cancel_dialog $save_offer
        then
            mv "$conf_temp" "$conf_file"
        fi
        return 1
        ;;
    esac
    step=`expr $step - 1`
    done
    return 0
}



# Set the value of a name=value string in a config file to the 
# specified value.  
#
# usage: set_bare_value file name value
#
set_config_value() {
    sed -i "s|^\($2\s*[:=]\s*\).*$|\1$3|" $1
}

# Retrieve the configuration value for the given name from the
# given configuration file.  Output value to stdout.
#
# usage: get_config file name
#
get_config() {
    sed -n "s|^$2\s*[:=]\s*\(.*\S\)\s*$|\1|p" $1
}

# Create a directory owned by root if it does not already exist.
#
# usage create_dir dir...
#
create_dir() {
    for dir in "$@"
    do
        if [ ! -d $dir ]
        then
            mkdir $dir
        fi
        chown root:root $dir
        chmod 755 $dir
    done
}

# directories required for install of ftp_upload
#
CODE=/opt/ftp_upload
CONFIG=/etc/opt/ftp_upload
VAR=/var/opt/ftp_upload
LOG=$VAR/log
INC=$VAR/incoming
PROC=$VAR/processed
INITD=/etc/init.d

NOLOGINSHELL=/bin/false

# web directory from which to wget ftp_upload source files
FUPDIR=https://raw.githubusercontent.com/dougkerr/ftp_upload/configupload/FTP_Upload/src
FUPDIR2=https://raw.githubusercontent.com/dougkerr/ftp_upload-1/configupload/FTP_Upload/initscript

main() {
    cfg=upload.cfg
    
	# XXX add verification that we're running as root

    # download the required system software
    #
    echo "***** Download and install required system software"
    apt-get -q install openssh-server
    apt-get -q install sshpass
    apt-get -q install tightvncserver
    apt-get -q install vsftpd
    apt-get -q -y install samba

    # create the ftp_upload directories for code, log and images
    #
    echo "***** Create required directories"
    create_dir $CODE
    create_dir $CONFIG
    create_dir $VAR
    create_dir $LOG
    create_dir $INC
    create_dir $PROC
    # XXX chown $cam_user:$cam_user $INC


    # download the current ftp_upload source
    #
    echo "***** Download Neighborhood Guard software"
    rm -f $CODE/ftp_upload.py
    wget -q -P $CODE $FUPDIR/ftp_upload.py
    rm -f $CONFIG/*.conf
    wget -q -P $CODE $CONFIG/ftp_upload_example.conf
    
    # download and install the init script
    #
    src=$FUPDIR2/ftp_upload
    tgt=$INITD/ftp_upload
    rm -f $tgt
    wget -q -P $INITD $src
    chmod 755 $tgt
    chown root:root $tgt
    # update-rc.d ftp_upload defaults 
    # XXX if starts immediately, need to wait

    # set up the config values for ftp_upload's localsettings.py
    #
    echo "***** Configure Neighborhood Guard software"
    conf="$CONFIG/ftp_upload.conf"
    cp "$CONFIG/ftp_upload_example.conf" "$conf"
    
	set_config_value $conf ftp_server "`get_config $cfg cs_name`"
    set_config_value $conf ftp_username "`get_config $cfg cs_user`"
    set_config_value $conf ftp_password "`get_config $cfg cs_pass`"
    set_config_value $conf ftp_destination "/`get_config $cfg cs_ftp_dir`"
	set_config_value $conf retain_days "`get_config $cfg um_retain_days`"
    set_config_value $conf incoming_location $INC
    set_config_value $conf processed_location $PROC

    # configure for vsftpd.  It seems that the only simple way to
    # deny login to the camera user but allow the camera user to connect
    # via FTP is to put the no-login-shell into /etc/shells then set
    # the camera user's shell to it.  If it's not in /etc/shells,
    # vsftpd won't allow the user to connect via FTP
    #
    echo "***** Configure camera FTP access to this machine"
    if ! grep "^$NOLOGINSHELL\$" /etc/shells > /dev/null
    then
        echo $NOLOGINSHELL >> /etc/shells
    fi

    # create the local ftp user account for the camera(s)
    # and give it access to the incoming images dir
    #
    cam_user=`get_config $cfg um_cam_user`
    if id -u $cam_user > /dev/null 2>&1
    then
        deluser --quiet $cam_user 
    fi
    useradd -d $INC -U -s $NOLOGINSHELL $cam_user
    chgrp $cam_user $INC
    chmod 775 $INC
    echo "$cam_user:`get_config $cfg um_cam_pass`" | chpasswd

    # set up this machine's NetBIOS name 
    #
    hostname="`get_config $cfg um_name`"
    sed -i "s/^.*$/$hostname/" /etc/hostname
    sed -i "s/127\\.0\\.1\\.1.*$/127.0.1.1\t$hostname/" /etc/hosts
}

if [ ! $UNIT_TEST_IN_PROGRESS ]
then
    main
fi


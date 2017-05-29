#!/bin/sh

. ./utils.sh
. ./confui.sh

# install the package or packages indicated in the first argument
install_wait() {
	local pkgs="$1"
	local wtime=5
    local trys=12
    while ! apt-get -qqy install $pkgs
    do
    	echo -n "Install attempt failed: $1. Will retry for one minute  "
    	echo "Waiting $wtime seconds and trying again."
    	sleep "$wtime"
    	trys=`expr $trys - 1`
    	if [ "$trys" = 0 ]
    	then
    		echo "CANNOT INSTALL REQUIRED SYSTEM SOFTWARE"
    		return 1
    	fi
    done
    return 0
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

SCRIPTLOG=./configupload.log

NOLOGINSHELL=/bin/false

# github directories from which to wget ftp_upload source files
GHREPO=https://raw.githubusercontent.com/dougkerr/ftp_upload-1/configupload
FUPDIR=$GHREPO/FTP_Upload/src
FUPDIR2=$GHREPO/FTP_Upload/initscript

main() {
	local cfg=$conf_file
    
	# verify that we're root
	if [ `whoami` != root -a "$UI_TESTING" != 1 ]
	then
		echo "$0: You must run this script as root."
		echo "Try sudo $0"
		exit 1
	fi
	
	# Get the config info from the user.
	# Exit if the user cancels
	#
	if ! get_info
	then
	    exit 1
	fi
	
	echo `date --rfc-3339=seconds` "Start configupload" >> $SCRIPTLOG

    # set up this machine's NetBIOS name
    #
    echo "***** Update this machine's hostname"
    local hostname="`get_config $cfg um_name`"
    hostnamectl set-hostname $hostname
    sed -i "s/127\\.0\\.1\\.1.*$/127.0.1.1\t$hostname/" /etc/hosts
    
    echo "***** Update the existing system software"
	# update and upgrade the system
    apt-get update >> $SCRIPTLOG
    # XXX apt-get upgrade
    
    # install the required system software
    #
    echo "***** Download and install new required system software"
    
	# install debconf-utils so we can pre-configure proftpd not to ask the user
	# whether it should be run under inetd or standalone
    install_wait debconf-utils >> $SCRIPTLOG
    echo "proftpd-basic shared/proftpd/inetd_or_standalone select standalone" \
    	| debconf-set-selections >> $SCRIPTLOG
    	
	# install all the required packages
	local pkgs="openssh-server sshpass tightvncserver proftpd samba"
    install_wait "$pkgs" >> $SCRIPTLOG

    # create the ftp_upload directories for code, log and images
    #
    echo "***** Create required directories"
    create_dir $CODE
    create_dir $CONFIG
    create_dir $VAR
    create_dir $LOG
    create_dir $INC
    create_dir $PROC

    # download the current ftp_upload source
    #
    echo "***** Install Neighborhood Guard software"
	local our_dir=`dirname $(readlink -e "$0")`
	cp $our_dir/../src/ftp_upload.py $CODE
	cp $our_dir/../src/ftp_upload_example.conf $CONFIG
    
    # download and install the init script
    #
    local tgt=$INITD/ftp_upload
    rm -f $tgt
	cp $our_dir/../initscript/ftp_upload $tgt
    chmod 755 $tgt
    chown root:root $tgt
    update-rc.d ftp_upload defaults 

    # set up the config values for ftp_upload
    #
    echo "***** Configure Neighborhood Guard software"
    local conf="$CONFIG/ftp_upload.conf"
    cp "$CONFIG/ftp_upload_example.conf" "$conf"
    
	set_config_value $conf ftp_server "`get_config $cfg cs_name`"
    set_config_value $conf ftp_username "`get_config $cfg cs_user`"
    set_config_value $conf ftp_password "`get_config $cfg cs_pass`"
    set_config_value $conf ftp_destination "/`get_config $cfg cs_ftp_dir`"
	set_config_value $conf retain_days "`get_config $cfg um_retain_days`"
    set_config_value $conf incoming_location $INC
    set_config_value $conf processed_location $PROC

    # configure for camera FTP.  It seems that the only simple way to
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

    # create the local FTP user account for the camera(s)
    # and give it access to the incoming images dir
    #
    cam_user=`get_config $cfg um_cam_user`
    if id -u $cam_user > /dev/null 2>&1
    then
        deluser --quiet $cam_user 
    fi
    useradd -d $INC -U -s $NOLOGINSHELL $cam_user
    chown $cam_user:$cam_user $INC    
    chmod 775 $INC
    echo "$cam_user:`get_config $cfg um_cam_pass`" | chpasswd
    
    # limit FTP users to their login directory and below 
	# XXX should be done in an idempotent way
	local cf=/etc/proftpd/proftpd.conf
	echo "# The configuration below was added by the configupload script" >> $cf
	echo 'DefaultRoot ~' >> $cf
	
	# set proftpd up to be run on boot and restart it with the new config
	update-rc.d proftpd defaults
	service proftpd restart

    
    echo "***** Start ftp_upload"
    service ftp_upload start
}

if [ ! $UNIT_TEST_IN_PROGRESS ]
then
    main
fi

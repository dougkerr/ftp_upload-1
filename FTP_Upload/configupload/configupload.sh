#!/bin/sh

. ./utils.sh
. ./confui.sh
. ./keys.sh

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
code_dir=/opt/ftp_upload
config_dir=/etc/opt/ftp_upload
var_dir=/var/opt/ftp_upload
log_dir=$var_dir/log
inc_dir=$var_dir/incoming
proc_dir=$var_dir/processed
initd_dir=/etc/init.d

# log file for this script
scriptlog=./configupload.log

# shell to use as a no-login shell for the camera's FTP account
nologinshell=/bin/false

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
	
	echo `date --rfc-3339=seconds` "Start configupload" >> $scriptlog

    # set up this machine's NetBIOS name
    #
    echo "***** Update this machine's hostname" | tee -a $scriptlog
    local hostname="`get_config $cfg um_name`"
    hostnamectl set-hostname $hostname
    sed -i "s/127\\.0\\.1\\.1.*$/127.0.1.1\t$hostname/" /etc/hosts
    
    echo "***** Update the available system software listing"| tee -a $scriptlog
	# update and upgrade the system
    apt-get update >> $scriptlog
    # XXX apt-get upgrade
    
    # install the required system software
    #
    echo "***** Download and install new required system software" \
        | tee -a $scriptlog
    
	# install debconf-utils so we can pre-configure proftpd not to ask the user
	# whether it should be run under inetd or standalone
    install_wait debconf-utils >> $scriptlog
    echo "proftpd-basic shared/proftpd/inetd_or_standalone select standalone" \
    	| debconf-set-selections >> $scriptlog
    	
	# install all the required packages
	local pkgs="openssh-server sshpass tightvncserver proftpd samba"
    install_wait "$pkgs" >> $scriptlog

    # create the ftp_upload directories for code, log and images
    #
    echo "***** Create required directories" | tee -a $scriptlog
    create_dir $code_dir
    create_dir $config_dir
    create_dir $var_dir
    create_dir $log_dir
    create_dir $inc_dir
    create_dir $proc_dir

    # download the current ftp_upload source
    #
    echo "***** Install Neighborhood Guard software" | tee -a $scriptlog
	local our_dir=`dirname $(readlink -e "$0")`
	cp $our_dir/../src/ftp_upload.py $code_dir
	cp $our_dir/../src/ftp_upload_example.conf $config_dir
    
    # download and install the init script
    #
    local tgt=$initd_dir/ftp_upload
    rm -f $tgt
	cp $our_dir/../initscript/ftp_upload $tgt
    chmod 755 $tgt
    chown root:root $tgt
    update-rc.d ftp_upload defaults 

    # set up the config values for ftp_upload
    #
    echo "***** Configure Neighborhood Guard software" | tee -a $scriptlog
    local conf="$config_dir/ftp_upload.conf"
    cp "$config_dir/ftp_upload_example.conf" "$conf"
    
	set_config_value $conf ftp_server "`get_config $cfg cs_name`"
    set_config_value $conf ftp_username "`get_config $cfg cs_user`"
    set_config_value $conf ftp_password "`get_config $cfg cs_pass`"
    set_config_value $conf ftp_destination "/`get_config $cfg cs_ftp_dir`"
	set_config_value $conf retain_days "`get_config $cfg um_retain_days`"
    set_config_value $conf incoming_location $inc_dir
    set_config_value $conf processed_location $proc_dir

    # configure for camera FTP.  It seems that the only simple way to
    # deny login to the camera user but allow the camera user to connect
    # via FTP is to put the no-login-shell into /etc/shells then set
    # the camera user's shell to it.  If it's not in /etc/shells,
    # vsftpd won't allow the user to connect via FTP
    #
    echo "***** Configure camera FTP access to this machine" | tee -a $scriptlog
    if ! grep "^$nologinshell\$" /etc/shells > /dev/null
    then
        echo $nologinshell >> /etc/shells
    fi

    # create the local FTP user account for the camera(s)
    # and give it access to the incoming images dir
    #
    cam_user=`get_config $cfg um_cam_user`
    if id -u $cam_user > /dev/null 2>&1
    then
        deluser --quiet $cam_user 
    fi
    useradd -d $inc_dir -U -s $nologinshell $cam_user
    chown $cam_user:$cam_user $inc_dir    
    chmod 775 $inc_dir
    echo "$cam_user:`get_config $cfg um_cam_pass`" | chpasswd
    
    # limit FTP users to their login directory and below 
	# XXX should be done in an idempotent way
	local cf=/etc/proftpd/proftpd.conf
	echo "# The configuration below was added by the configupload script" >> $cf
	echo 'DefaultRoot ~' >> $cf
	
	# set proftpd up to be run on boot and restart it with the new config
	update-rc.d proftpd defaults
	service proftpd restart
	
	echo "***** Set up SSH key pair with cloud server" | tee -a $scriptlog
	local luser="`getluser`"
	local cs_user="`get_config $cfg cs_user`"
	local cs_name="`get_config $cfg cs_name`"
	local cs_pass="`get_config $cfg cs_pass`"
	setupkeypair "$luser" "$cs_user@$cs_name" "$cs_pass" "$scriptlog"

    
    echo "***** Start ftp_upload" | tee -a $scriptlog
    service ftp_upload start
    
    echo "***** Done" | tee -a $scriptlog
}

if [ ! $UNIT_TEST_IN_PROGRESS ]
then
    main
fi


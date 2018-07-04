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


# directories required for install of ftp_upload and cktunnel
#
code_dir=/opt/ftp_upload
config_dir=/etc/opt/ftp_upload
var_dir=/var/opt/ftp_upload
log_dir=$var_dir/log
inc_dir=$var_dir/incoming
proc_dir=$var_dir/processed
initd_dir=/etc/init.d
tun_code_dir=/opt/cktunnel
tun_config_dir=/etc/opt/cktunnel
tun_var_dir=/var/opt/cktunnel
tun_log_dir=$tun_var_dir/log

# log file for this script
scriptlog=configupload.log

# shell to use as a no-login shell for the camera's FTP account
nologinshell=/bin/false

# global to hold the name of the section that produced an unexpected error
#
task=""

# on unexpected exit, print an error message with the approximate location
# of the error
#
errorexit() {
    echo "An unexpected error occurred while $task." | tee -a "$scriptlog" >&2
    echo "Please see the log file: $scriptlog." | tee -a "$scriptlog" >&2
    exit 1
}

configure() {
    local cfg=$conf_file
    
    # Set up to catch unexpected errors and notify user
    #
    trap errorexit EXIT
    set -e
    
    # set up this machine's NetBIOS name
    #
    task="updating this machine's hostname"
    echo "***** $task" | tee /dev/tty
    local hostname="`get_config $cfg um_name`"
    hostnamectl set-hostname $hostname
    sed -i "s/127\\.0\\.1\\.1.*$/127.0.1.1\t$hostname/" /etc/hosts
    
    task="updating the available system software listing"
    echo "***** $task" | tee /dev/tty
    # update and upgrade the system
    apt-get update  # info output to log
    # XXX apt-get upgrade
    
    # install the required system software
    #
    task="downloading and installing new required system software"
    echo "***** $task" | tee /dev/tty
    
    # install debconf-utils so we can pre-configure proftpd not to ask the user
    # whether it should be run under inetd or standalone
    install_wait debconf-utils  # info output to log
    echo "proftpd-basic shared/proftpd/inetd_or_standalone select standalone" \
        | debconf-set-selections   # info output to log
        
    # install all the required packages
    local pkgs="openssh-server sshpass tightvncserver proftpd samba"
    install_wait "$pkgs"    # info output to log

    # create the ftp_upload directories for code, log and images
    #
    task="creating required directories"
    echo "***** $task" | tee /dev/tty
    create_dir $code_dir
    create_dir $config_dir
    create_dir $var_dir
    create_dir $log_dir
    create_dir $inc_dir
    create_dir $proc_dir
    create_dir $tun_code_dir
    create_dir $tun_config_dir
    create_dir $tun_var_dir
    create_dir $tun_log_dir

    # download the current ftp_upload source
    #
    task="installing Neighborhood Guard software"
    echo "***** $task" | tee /dev/tty
    local our_dir=`dirname $(readlink -e "$0")`
    cp $our_dir/../src/ftp_upload.py $code_dir
    cp $our_dir/../src/ftp_upload_example.conf $config_dir
    cp $our_dir/../tunnel/cktunnel.sh $tun_code_dir/cktunnel
    chmod +x $tun_code_dir/cktunnel
    cp $our_dir/../configupload/utils.sh $tun_code_dir
    cp $our_dir/../tunnel/cktunnel_example.conf $tun_config_dir

    # install the ftp_upload init script
    #
    local tgt=$initd_dir/ftp_upload
    rm -f $tgt
    cp $our_dir/../initscript/ftp_upload $tgt
    chmod 755 $tgt
    chown root:root $tgt
    update-rc.d ftp_upload defaults 

    # install the cktunnel init script
    #
    tgt=$initd_dir/cktunnel
    rm -f $tgt
    cp $our_dir/../initscript/cktunnel $tgt
    # set user that cktunnel will run under
    set_config_value $tgt RUNASUSER `getluser`
    chmod 755 $tgt
    chown root:root $tgt
    update-rc.d cktunnel defaults 

    # set up the config values for ftp_upload & cktunnel
    #
    task="configuring Neighborhood Guard software"
    echo "***** $task" | tee /dev/tty

    
    # ftp_upload conf
    local conf="$config_dir/ftp_upload.conf"
    cp "$config_dir/ftp_upload_example.conf" "$conf"
    set_config_value $conf ftp_server "`get_config $cfg cs_name`"
    set_config_value $conf ftp_username "`get_config $cfg cs_user`"
    set_config_value $conf ftp_password "`get_config $cfg cs_pass`"
    set_config_value $conf ftp_destination "/`get_config $cfg cs_ftp_dir`"
    set_config_value $conf retain_days "`get_config $cfg um_retain_days`"
    set_config_value $conf incoming_location $inc_dir
    set_config_value $conf processed_location $proc_dir

    # cktunnel conf
    conf="$tun_config_dir/cktunnel.conf"
    cp "$tun_config_dir/cktunnel_example.conf" "$conf"
    local user="`get_config $cfg cs_user`"
    local server="`get_config $cfg cs_name`"
    set_config_value $conf acct "$user@$server"

    # configure for camera FTP.  It seems that the only simple way to
    # deny login to the camera user but allow the camera user to connect
    # via FTP is to put the no-login-shell into /etc/shells then set
    # the camera user's shell to it.  If it's not in /etc/shells,
    # vsftpd won't allow the user to connect via FTP
    #
    task="configuring camera FTP access to this machine"
    echo "***** $task" | tee /dev/tty
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
    if ! grep -E '^DefaultRoot\s+~' "$cf" > /dev/null
    then
        echo \
           "# The configuration below was added by the configupload script" \
            >> $cf
        echo 'DefaultRoot ~' >> $cf
    fi
    
    # set proftpd up to be run on boot and restart it with the new config
    update-rc.d proftpd defaults
    service proftpd restart
    
    task="setting up SSH key pair with cloud server"
    echo "***** $task" | tee /dev/tty
        local luser="`getluser`"
    local cs_user="`get_config $cfg cs_user`"
    local cs_name="`get_config $cfg cs_name`"
    local cs_pass="`get_config $cfg cs_pass`"
    setupkeypair "$luser" "$cs_user@$cs_name" "$cs_pass"
    # create tunnel flags dir on cloud server for cktunnel
    ssh "$cs_user@cs_name" "mkdir -f -m 700 .tunnelflags" 

    
    task="starting ftp_upload"
    echo "***** $task" | tee /dev/tty
    service ftp_upload start
    
    task="starting cktunnel"
    echo "***** $task" | tee /dev/tty
    service cktunnel start
    
    # Turn off error trap
    set +e
    trap - EXIT
    
    echo "***** done" | tee /dev/tty
}


main() {
    # verify that we're root
    #
    if [ `whoami` != root -a "$UI_TESTING" != 1 ]
    then
        echo "$0: You must run this script as root."
        echo "Try sudo $0"
        exit 1
    fi
    
    # start the log
    echo `date --rfc-3339=seconds` "Start configupload" >> $scriptlog

    
    # Get the config info from the user.
    # Exit if the user cancels
    #
    if ! get_info
    then
        exit 1
    fi
    
    # configure this machine
    configure >> $scriptlog 2>&1
}
    

if [ ! $UNIT_TEST_IN_PROGRESS ]
then
    main
fi


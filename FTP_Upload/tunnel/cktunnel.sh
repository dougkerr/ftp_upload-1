#!/bin/sh
# This script polls an Internet-accessible Linux/Unix server (the "intermediate
# server") looking for requests from a client to establish an ssh tunnel from
# the intermediate server to a specific port on this machine (e.g., port 5900
# for VNC, port 22 for SSH) to allow remote connections to made to this machine
# from a client machine.  The client machine must also establish an ssh tunnel
# to the intermediate server to complete its connection to this machine.
#
# The client writes a request file on the intermediate server containing the
# port number to be used on the intermediate server's localhost interface as
# the connection point between its tunnel to the intermediate server and the
# tunnel from the intermediate server to this machine.  This script then reads
# and removes the request file, and leaves a reply file containing the port
# number and the date & time.
#
# N.B.: For this script to work, an ssh key pair must be set up.  This machine
# will use the private key to authenticate to the intermediate server.  The
# intermediate server must have the public key in the .ssh/authorized_keys file
# (presuming the intermediate server is Linux based) of the account used to
# access the server.  Note also that this script should be executed under the
# UID of the user who owns the private key.  Otherwise, the keyfile will have
# to be set specially to the approriate private key.
#

. ./utils.sh

# find the configuration file
#
for d in . /etc/opt/cktunnel /etc/cktunnel /etc
do
    path="$d/cktunnel.conf"
    if [ -f "$path" ]
    then
        break
    else
        path=""
    fi
done
if [ -z "$path" ] 
then
    echo "$0: Can't find configuration file!" 1>&2
    exit 1
fi

# load the configuration values
#
mach_name=`get_config "$path" mach_name "$(hostname)"`
sleep_time=`get_config "$path" sleep_time 15`
acct=`get_config "$path" acct`
flagsdir=`get_config "$path" flagsdir .tunnelflags`
keyfile=`get_config "$path" keyfile ~/.ssh/id_rsa`
def_lclport=`get_config "$path" def_lclport 22`

if [ -z "$acct" ]
then
    echo "$0: No intermediate server account specified!" 1>&2
    exit 1
fi
    

# Set up the file paths (relative the server account's home directory) of
# the request and reply files.
#
requestfp=$flagsdir/$mach_name.request
replyfp=$flagsdir/$mach_name.reply

# Set the local endpoing for the tunnel.  Someday this will have a command line
# option XXX
lclport=$def_lclport

# loop forever looking for a tunnel request
while true; do

    # If there's a tunnel request file on the server, read the requested
    # port number from the file and remove the file. Note small race condition
    # window between cat and rm.  If caught by this, user will just have to 
    # re-run the request. Could be solved by using hard links on the server
    #
    port=`ssh -i $keyfile $acct "cat $requestfp 2>/dev/null; rm -f $requestfp"`

    # If there's a requested port, write the reply file and create a
    # tunnel from that port on the intermediate server to port 5900
    # on this machine
    #
    if [ -n "$port" ]; then
        ssh -i $keyfile $acct "echo $port `date` > $replyfp"

        # ssh args to set up tunnel for VNC access
        t1="-R $port:localhost:$lclport"

        # Log the action to the console
        echo `date` Creating tunnel $t1

        # Set up tunnel in "background"
        ssh -f -i $keyfile -N $t1 $acct
    fi

    # sleep before checking again for a request
    sleep $sleep_time
done

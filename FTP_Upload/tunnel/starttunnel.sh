#!/bin/sh

# This script, in conjunction with the cktunnel script, connects an SSH client
# on the local machine to a SSH server on a target machine via SSH tunnels
# from the local machine to an Internet-accessible Linux/Unix server
# (the "intermediate server") and from the intermediate server to the target
# machine. This allows a client to connect to a target machine when both
# are behind firewalls and not otherwise accessible to each other.
#
# This script writes a tunnel request file to the intermediate server on a
# specified account, and waits for the cktunnel script running on the target
# machine to acknowledge the request and set up a tunnel from the server to
# the target machine.  This script then sets up a corresponding tunnel from
# the local machine to the server.  Once the tunnels are set up, the local
# user can establish an SSH connection to the target machine by connecting
# the SSH client to the local port specified in the starttunnel command.
#
# For example, the user might execute this script as follows:
#
#      starttunnel target_machine 12345
#
# where "target_machine" is the name of the target machine as defined in its
# cktunnel script (not necessarily related to its DNS name, NetBIOS name, or 
# other name) and "12345" is the port number of the endpoing of the tunnel on
# the local machine.  Once the tunnel is established, the user would start
# the SSH client and connect it localhost port 12345 to establish the
# connection to the target machine.
#
# This script selects a random port number in the ephemeral range as the
# endpoint for the tunnels on the intermediate server, and communicates it
# to the target machine's cktunnel script in the request file it places on
# the server.
#

# #### Configuration section ####

# Name of the account, including host name, that will be used as the
# Internet-accessible endpoint of the tunnels, e.g., myaccount@myhost.com
#ACCT=myaccount@myhost.com
ACCT=testuser@10.0.2.8

# Name of the directory, relative to the above account's home directory,
# in which the flag files will be stored.
# We recommend that it be hidden.
# We STRONGLY recommend that it be readable only to owner, e.g., mode 700.
FLAGSDIR=.tunnelflags

# File on this machine containing the private key that will be used by SSH
# to access the above account on the intermediate server.
KEYFILE=~/.ssh/id_rsa

# #### End of configuration section ####

# IANA ephemeral port range
LOPORT=49152
HIPORT=65535

# Pick a random port in the ephemeral range
RANDPORT=`shuf -i $LOPORT-$HIPORT -n 1`


if [ $# -ne 2 ]
then
    echo "Usage: starttunnel target_machine_name local_port"
    exit 1
fi


# Set the name of the target machine and the port on this machine to
# connect to.
#
target=$1
local_port=$2

# Set up the file paths (relative the server account's home directory) of
# the request and reply files.
#
requestfp=$FLAGSDIR/$target.request
replyfp=$FLAGSDIR/$target.reply

int_server_port=$RANDPORT
echo "$int_server_port requested on $ACCT"

# Script to execute on the intermediate server
#
rscript="rm -f $replyfp; \
echo $int_server_port > $requestfp; \
while [ ! -e $replyfp ]; do \
  sleep 2; \
done; \
cat $replyfp; \
echo Tunnel ready... ; \
sleep 99999"

# Tunnel description for SSH
#
t1="-L $local_port:localhost:$RANDPORT"

# Start the tunnel
#
ssh -C -i $KEYFILE $t1 $ACCT "$rscript"

# see if an ssh key pair is already set up between the current user on 
# this machine and the cloud server. If not, set one up now.
# usage: setupkeypair local_user remotuser@remoteserver remote_passwd
#
setupkeypair () {
    local luser=$1
    local racct=$2
    local rpass=$3

    # build the sudo prefix to run a command as the local user with a
    # controlling tty, and the su prefix to run as the local user
    # but without a controlling tty
    #
    SUDOLU="sudo -u $luser -H" 

    # see if we have a private key.
    # If we do, see if it's bad or needs a passphrase. If either or these
    # is true, move the key aside
    #
    local genpubkey
    local privkeyfile=~/.ssh/id_rsa 
    if [ -e $privkeyfile ]
    then
        genpubkey=""
        if ! genpubkey="`$SUDOLU ssh-keygen -y -f $privkeyfile < /dev/null`"
        then
            echo Moving bad private key aside.
            mv $privkeyfile $privkeyfile.orig
        fi
    fi

    # see if a key pair is already set up.
    # This test has the side effect of putting the remote machine's
    # fingerprint in the local user's known_hosts file, if the
    # remote machine can be contacted
    #
    local sshmsg
    if sshmsg="`echo | $SUDOLU ssh \
        -o 'PreferredAuthentications=publickey' \
        -o 'StrictHostKeyChecking=no' $racct exit 2>&1`"
    then
        echo key pair IS already set up with $racct
        return 0
    fi

    # if the above test failed but we don't see "permission denied" in the
    # output (meaning that we reached the host but don't have a key
    # that it will accept), then some other, non-permission-related
    # failure has occurred, e.g., we can't reach the host
    #
    if ! echo "$sshmsg" | grep -i "permission denied"
    then
        echo other error with ssh:
        echo "$sshmsg"
        return 1
    fi

    echo no key pair set up with $racct, setting one up now...

    # if there's an existing private key, then check for a public key.
    # If we don't have a public key, or the one we have doesn't match
    # the private key, save the correct public key to a new file
    #
    if genpubkey="`echo | $SUDOLU ssh-keygen -y -f $privkeyfile`"
    then
        local pubkeyfile=~/.ssh/id_rsa.pub
        local pubkey="`sed 's/\([^ ][^ ]*  *[^ ][^ ]*\).*$/\1/' $pubkeyfile`"
        if [ $? != 0 -o "$pubkey" != "$genpubkey" ]
        then
            pubkeyfile=~/.ssh/id_rsa.uploadconfig.pub
            echo "$genpubkey" "$luser@$um_name" | \
                $SUDOLU tee $pubkeyfile > /dev/null
        fi

    # otherwise (we don't have a good private key), generate the key pair
    #
    else
        echo "Generating new key pair."
        echo | $SUDOLU ssh-keygen -t rsa
    fi

    echo Have key pair priv=$privkeyfile pub=$pubkeyfile

    # copy pub key to cloud server
    #
    $SUDOLU sshpass -p"$cs_pass" ssh-copy-id -f -i "$pubkeyfile" "$racct" 

    # now see if we can log in
    #
    if ! sshmsg="`echo | $SUDOLU ssh \
        -o 'PreferredAuthentications=publickey' \
        -o 'StrictHostKeyChecking=no' $racct exit 2>&1`"
    then
        echo Cannot ssh to server even though we just set up a key pair.
        return 1
    fi

    echo Successfully set up key pair!
    return 0
}


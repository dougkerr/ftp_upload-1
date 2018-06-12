# tell the script under test not to proceed with normal execution 

UNIT_TEST_IN_PROGRESS=1

. ../keys.sh 

# XXX configure these more globally?
test_racct="testuser@10.0.2.6"
test_rpass=testpass
test_privkey=$HOME/.ssh/id_rsa
test_user=`whoami`

setUp() {
    # delete the remote host's SSH info
    sshpass -p"$test_rpass" ssh "$test_racct" rm -rf .ssh
    sshpass -p"$test_rpass" ssh "$test_racct" 'ls -d .ssh > /dev/null 2>&1'
    if [ "$?" -ne 2 ]   # status 2 means ls didn't find .ssh
    then
        fail "setUp's removal of remote host's .ssh failed."
    fi

    # delete the local host's SSH info
    rm -rf $HOME/.ssh
    ls -d $HOME/.ssh > /dev/null 2>&1
    if [ "$?" -ne 2 ]   # status 2 means ls didn't find .ssh
    then
        fail "setUp's removal of local host's .ssh failed."
    fi

    # add the remote test machine into the local known_hosts file
    # to prevent SSH from complaining
    ssh -o 'PreferredAuthentications=publickey' -o 'StrictHostKeyChecking=no' \
        "$test_racct" true > /dev/null 2>&1
}

# run setupkeypair(), check it's return status and also verify that an
# SSH connection can be established with the remote host
#
run_setupkeypair() {
    if ! setupkeypair $test_user "$test_racct" "$test_rpass" > /dev/null 2>&1
    then
        fail setupkeypair returns failure
    fi
    if ! ssh "$test_racct" true
    then
        fail "Cannot execute remote command after key pair set up"
    fi
}

test_no_initial_keys() {
    run_setupkeypair
}

test_keypair_already_set_up() {
    run_setupkeypair
    # keypair now already set up
    run_setupkeypair
}

test_bogus_host() {
    # fastest to use a host that's up but not running SSH
    setupkeypair $test_user testuser@10.0.2.1 "$test_rpass" > /dev/null 2>&1
    status=$?
    if [ "$status" -ne 1 ]
    then
        fail "Incorrect status return from bogus host test: $status"
    fi
}

test_existing_key_pair_but_not_set_up() {
    # generate a key pair to be the "existing" one
    echo | ssh-keygen -q -t rsa -f $test_privkey > /dev/null 2>&1

    run_setupkeypair
}

test_existing_key_with_passphrase() {
    # create a key pair with a passphrase on the private key
    ssh-keygen -q -t rsa -N testphrase -f "$test_privkey"

    run_setupkeypair
    if [ ! -e "$test_privkey.orig" ]
    then
        fail "Old key file with passphrase $test_privkey.orig does not exist"
    fi
}

test_existing_bad_key() {
    # create a key pair
    ssh-keygen -q -t rsa -f "$test_privkey" < /dev/null > /dev/null 2>&1
    # damage the private key by deleting the second line in the file
    sed --in-place 2d "$test_privkey"

    run_setupkeypair
    if [ ! -e "$test_privkey.orig" ]
    then
        fail "Old, bad key file $test_privkey.orig does not exist"
    fi
}

test_private_but_no_public_key() {
    # create a key pair
    ssh-keygen -q -t rsa -f "$test_privkey" < /dev/null > /dev/null 2>&1
    # remove the public key
    rm "$test_privkey.pub"

    run_setupkeypair
    if [ ! -e "$test_privkey.pub" ]
    then
        fail "Public key file $test_privkey.pub does not exist"
    fi
}

test_private_but_bad_public_key() {
    # create a key pair
    ssh-keygen -q -t rsa -f "$test_privkey" < /dev/null > /dev/null 2>&1
    # damage the public key by deleting a few chars of key data
    sed --in-place 's/ ..../ /' "$test_privkey.pub"

    run_setupkeypair
    if [ ! -e "$test_privkey.pub" ]
    then
        fail "Public key file $test_privkey.pub does not exist"
    fi
    if [ ! -e "$test_privkey.pub.orig" ]
    then
        fail "Old public key not moved aside"
    fi
}


. `which shunit2`    

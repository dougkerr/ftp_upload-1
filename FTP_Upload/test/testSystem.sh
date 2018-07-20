#!/bin/sh

# simple end-to-end system tests for ftp_upload and the tunnel mechanism
#
# This is intended to be run after the installation of the software 
# via configupload is complete.  It uses configuration files and values
# generated by configupload. 
# To be successful, this script must be run:
# - after configupload has successfully installed the software.
# - under the same user account that was used to run configupload.
# - from the directory in which this script resides (i.e., cd to this
#   directory first).
#

. ../configupload/utils.sh

test_ftp_upload() {
    local image=../src/test/SampleImage.jpg
    local mainconf=../configupload/upload.conf
    local testdate=2010-01-01
    local testcam=camera1
    local fupldconf=/etc/opt/ftp_upload/ftp_upload.conf

    # get values from the configupload install config file
    local cs_name=`get_config "$mainconf" cs_name`
    local cs_user=`get_config "$mainconf" cs_user`
    local cs_ftp_dir=`get_config "$mainconf" cs_ftp_dir`
    local um_cam_user=`get_config "$mainconf" um_cam_user`
    local um_cam_pass=`get_config "$mainconf" um_cam_pass`

    # and one from the ftp_upload config file
    local inc_loc=`get_config "$fupldconf" incoming_location`


    if [ -z "$cs_ftp_dir" ]
    then
        local cs_path="$testdate"
    else
        local cs_path="$cs_ftp_dir/$testdate"
    fi

    # remove any preexisting test files on the cloud server
    #
    ssh $cs_user@$cs_name "rm -rf $cs_path; ls -d $cs_path > /dev/null 2>&1"
    local status=$?
    if [ "$status" -ne 2 ]
    then
        fail "Could not remove $cs_user@$cs_name:$cs_path"
    fi

    # FTP the test files to the local machine
    #
    ftp -n localhost << EndOfCommands
quote user $um_cam_user
quote pass $um_cam_pass
mkdir $testdate
mkdir $testdate/$testcam
put "$image" $testdate/$testcam/12-00-00-00001.jpg
put "$image" $testdate/$testcam/12-00-00-00002.jpg
put "$image" $testdate/$testcam/12-00-00-00003.jpg
quit
EndOfCommands
    ntestfiles=3

    # wait for ftp_upload to transfer the files
    #
    echo "(waiting for ftp_upload to transfer test files)"
    local count=0
    local st=3
    local wt=90
    # wait for the files to disappear from the local incoming files dir
    while [ `ls "$inc_loc/$testdate/$testcam" 2> /dev/null | wc -l` -ne 0 ]
    do
        if `test $count -ge $wt`
        then
            fail "\nWait for ftp_upload timed out."
            break
        fi
        sleep $st
        count=$((count+st))
        echo -n '*'
    done
    echo

    # verify that we have the files on the cloud server
    #
    local nfiles=`ssh $cs_user@$cs_name "ls $cs_path/$testcam|wc -l"`
    if [ "$nfiles" -ne $ntestfiles ]
    then
        fail "Wrong number of files transferred: $nfiles"
    fi
    echo "Success!"
}

. `which shunit2`

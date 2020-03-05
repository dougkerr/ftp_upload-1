# Notes on Installing Linux on an Upload Machine #

### OnLogic UEFI (BIOS) ###

#### Set the BIOS to boot from the installation medium. ####

We'll assume the installation medium is a USB stick (thumbdrive) that's been plugged into the machine.  On the OnLogic, assuming that the main SSD drive has no data on it, the BIOS will work it's way through several devices looking for a bootable medium until the USB stick is found and boot from it. 
 
 Configure the OnLogic machine to automatically boot up with power is applied (for recovery after a power failure) by going to the `Chipset` page of the BIOS, and setting the state of the `Auto Power On` item to `Enable`.

If the main drive already has an OS on it, boot into the BIOS by restarting the machine and repeatedly pressing the DEL key.  In the BIOS, use the right-arrow key to select the `Save & Exit` page, and in the `Boot Override` section, select the line that says `UEFI` followed by the name of the bootable USB stick.  Press `Enter` to boot from the stick.

#### Installing Ubuntu 18.04 Server ####

Select the lanuage.

Select the keyboard layout.

Configure the network interface (this should happen automatically).

Configure a proxy address if applicable.

Configure the Ubuntu mirror from which to download updates (the default should be fine).

Configure the Filesystem Setup.  Choose `Use An Entire Disk` (haven't explored using the Logical Volume Management, yet. Then choose your main drive to install Linux onto.  Finally, read through the summary of the Filesystem Setup and if correct, select `Done`.

In the `Profile Setup`, enter a name for the server (this can be changed later during the Neighborhood Guard software installation). Enter the user name for the maintenance account (the account that can run `sudo`), and enter password for that account.  For the examples below, we'll use `nguser` as the account name.

Under `SSH Setup`, select installation of the OpenSSH server by hitting the space bar.  OpenSSH will need to be installed eventually, and doing it now will make it easy to copy a private key for the cloud server into the upload machine, if you need to do that. 

On the `Featured Server Snaps` page, none of these need to be installed.

The Linux installation will then proceed, and security updates will be automatically installed.

Select the reboot option when the installation is complete.

At this point, the server should boot into Ubntu 18.04.  When it's through putting out boot messages to the screen, hit the `Enter` key and log in using the username and password you set up for the maintenance account.

Unlike the Desktop version of Ubuntu, the Server version does not have you set the timezone during the installation.  Set it now by using the `timedatectl` command.  If you do not know what timezones are available, you can list them using this command:

    timedatectl list-timezones
    
To set the timezone, use the `sudo timedatectl set-timezone` command followed by the name fo the timezone.  For example, to set Pacific Time in California, use this command:

    sudo timedatectl set-timezone America/Los_Angeles
    
#### Install the Cloud Server's Private Key (if required)

If you set up SSH access during the installation above, you can copy your private key into the upload machine from another system as shown below.  First, create the `.ssh` directory in the maintenance and set its permissions to 700:

    mkdir ~/.ssh
    chmod 700 ~/.ssh
    
From the machine containing the private key, copy the key to `.ssh/id_rsa` in the maintenance account, and set the mode to 600.  For example,

    scp *your_key*.pem nguser@*upload_machine*:.ssh/id_rsa
    ssh nguser@*upload_machine* chmod 600 '~/.ssh/id_rsa'



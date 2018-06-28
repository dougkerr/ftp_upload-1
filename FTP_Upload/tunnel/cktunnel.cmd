@echo off

rem This script polls an Internet-accessible Linux/Unix server (the
rem "intermediate server") looking for requests from a client to establish an
rem ssh tunnel from the intermediate server to port 5900 on this machine to
rem allow VNC remote desktop connections to made to this machine from a client
rem machine.  The client machine must also establish an ssh tunnel to the
rem intermediate server to complete its connection to this machine.
rem
rem The client writes a request file on the server containing the port number
rem to be used on the server's localhost interface as the connection point
rem between its tunnel to the server, and the tunnel from the server to
rem this machine.  This script then reads and removes the request file,
rem and leaves a reply file containing the port number and the date & time.
rem
rem For this script to work, an ssh key pair must be set up.  This machine
rem will use the private key to authenticate to the intermediate server.  The
rem intermediate server must have the public key in the .ssh/authorized_keys
rem file of the account used to access the server.
rem

setlocal enableDelayedExpansion

rem #### Configuration section ####

rem Name of the machine this script is running on, to differentiate it from
rem other machines requesting tunnels on the same host account
set MACH_NAME=highknoll

rem Number of seconds to wait between polling for a tunnel request
set SLEEP_TIME=15

rem Name of the account, including host name, that will be used as the
rem Internet-accessible endpoint of the tunnels, e.g., myaccount@myhost.com
set ACCT=ridgemont2@ridgemontng.org

rem Name of the directory, relative to the above account's home directory,
rem in which the flag files will be stored.
rem We recommend that it be hidden.
rem We STRONGLY recommend that it be readable only to owner, e.g., mode 700.
set FLAGSDIR=.tunnelflags

rem File on this machine containing the private key that will be used by plink
rem to access the above account on the intermediate server.
set KEYFILE=PuTTYKeys\highknoll.ppk

rem #### End of configuration section ####

rem Set up the file paths (relative the server account's home directory) of
rem the request and reply files.
rem
set requestfp=%FLAGSDIR%/%MACH_NAME%.request
set   replyfp=%FLAGSDIR%/%MACH_NAME%.reply

:loop
	rem If there's a tunnel request file on the server, read the requested
	rem port number from the file and remove the file.
	rem
	set port=
	for /f "usebackq tokens=*" %%t in (`plink -i %KEYFILE% %ACCT% "cat %requestfp% 2>/dev/null; rm -f %requestfp%"`) do set port=%%t
	
	rem If there's a requested port, write the reply file and create a
	rem tunnel from that port on the intermediate server to port 5900
	rem on this machine
	rem
	if NOT [!port!] == [] (
		plink -i %KEYFILE% %ACCT% echo !port! `date` ^> %replyfp%

		rem plink args to set up tunnel for VNC access
		set t1=-R !port!:localhost:5900

		rem Log the action to the console
		for /f "usebackq tokens=*" %%t in (`date /t`) do set a=%%t
		for /f "usebackq tokens=*" %%t in (`time /t`) do set b=%%t
		echo !a!!b! Creating tunnel !t1!

		rem Set up tunnel in "background"
		start "Tunnel !t1!" /min plink -i %KEYFILE% -N !t1! %ACCT%
	)
	rem Use ping to sleep some number of seconds
	ping 127.0.0.1 -n %SLEEP_TIME% > nul
goto loop

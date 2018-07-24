@echo off
rem ############################################################################
rem
rem Copyright (C) 2018 Neighborhood Guard, Inc.  All rights reserved.
rem Original author: Douglas Kerr
rem 
rem This file is part of FTP_Upload.
rem 
rem FTP_Upload is free software: you can redistribute it and/or modify
rem it under the terms of the GNU Affero General Public License as published by
rem the Free Software Foundation, either version 3 of the License, or
rem (at your option) any later version.
rem 
rem FTP_Upload is distributed in the hope that it will be useful,
rem but WITHOUT ANY WARRANTY; without even the implied warranty of
rem MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
rem GNU Affero General Public License for more details.
rem 
rem You should have received a copy of the GNU Affero General Public License
rem along with FTP_Upload.  If not, see <http://www.gnu.org/licenses/>.
rem
rem ############################################################################

rem This script, in conjunction with the cktunnel script, connects a VNC client
rem on the local machine to a VNC server on a target machine via SSH tunnels
rem from the local machine to an Internet-accessible Linux/Unix server
rem (the "intermediate server") and from the intermediate server to the target
rem machine. This allows a client to connect to a target machine when both
rem are behind firewalls and not otherwise accessible to each other.
rem
rem This script writes a tunnel request file to the intermediate server on a
rem specified account, and waits for the cktunnel script running on the target
rem machine to acknowledge the request and set up a tunnel from the server to
rem the target machine.  This script then sets up a corresponding tunnel from
rem the local machine to the server.  Once the tunnels are set up, the local
rem user can establish a VNC connection to the target machine by connecting
rem the VNC client to the local port specified in the starttunnel command.
rem
rem For example, the user might execute this script as follows:
rem
rem      starttunnel target_machine 12345
rem
rem where "target_machine" is the name of the target machine as defined in its
rem cktunnel script (not necessarily related to its DNS name, NetBIOS name, or 
rem other name) and "12345" is the port number of the endpoing of the tunnel on
rem the local machine.  Once the tunnel is established, the user would start
rem the VNC client and connect it localhost:12345 to establish the connection
rem to the target machine.
rem
rem This script selects a random port number in the ephemeral range as the
rem endpoint for the tunnels on the intermediate server, and communicates it
rem to the target machine's cktunnel script in the request file it places on
rem the server.
rem

rem #### Configuration section ####

rem Name of the account, including host name, that will be used as the
rem Internet-accessible endpoint of the tunnels, e.g., myaccount@myhost.com
rem set ACCT=dougk@wizardlx1
set ACCT=ridgemont2@ridgemontng.org

rem Name of the directory, relative to the above account's home directory,
rem in which the flag files will be stored.
rem We recommend that it be hidden.
rem We STRONGLY recommend that it be readable only to owner, e.g., mode 700.
set FLAGSDIR=.tunnelflags

rem File on this machine containing the private key that will be used by plink
rem to access the above account on the intermediate server.
set KEYFILE=%USERPROFILE%\Documents\id_rsa.ppk

rem #### End of configuration section ####

rem IANA ephemeral port range
set LOPORT=49152
set HIPORT=65535

rem Pick a random port in the ephemeral range
set /a PORTRANGE=%HIPORT% - %LOPORT% + 1
set /a RANDPORT=%random% %% %PORTRANGE% + %LOPORT%

set USAGE=Usage: starttunnel target_machine_name local_port

if "%1"=="" goto wrong_arg_count
if "%2"=="" goto wrong_arg_count
if "%3"=="" goto right_arg_count

:wrong_arg_count
echo %USAGE%
exit /b 1

:right_arg_count

rem Set the name of the target machine and the port on this machine to
rem connect to.
rem
set target=%1
set local_port=%2



rem Set up the file paths (relative the server account's home directory) of
rem the request and reply files.
rem
set requestfp=%FLAGSDIR%/%target%.request
set   replyfp=%FLAGSDIR%/%target%.reply

set int_server_port=%RANDPORT%
echo %int_server_port% requested on %ACCT%

rem Script to execute on the intermediate server
rem
set rscript=rm -f %replyfp%;^
echo %int_server_port% ^^^> %requestfp%;^
while [ ! -e %replyfp% ]; do^
	sleep 2;^
done;^
cat %replyfp%;^
echo Tunnel ready... ;^
sleep 99999

rem Tunnel description for plink
rem
set t1=-L %local_port%:localhost:%RANDPORT%

rem Start the tunnel
rem
plink -C -i %KEYFILE% %t1% %ACCT% %rscript%
exit /b



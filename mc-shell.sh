#!/bin/bash

# This was originally intended to be used as the default shell for a user with SSH access so it prevents the user from having full control on the server and gives them an easy interface to use. This is the user's preferred method of server administration after using some web interfaces and finding that none of them are ideal, and some are just hard to work with.

# KNOWN ISSUES:
# - exit codes are not being show in the log correctly. They are all 0.
# - the exit code for closing a console like RemoteBukkit Console with CTRL+C is 130, so this always reports an error to the logfile.

# DEVELOPMENT NOTES:
# - A way to restart the server if it's crashed.
# - Maybe use start-stop-daemon for starting and stopping screen and the server. This will allow us to get the pid for monitoring if the server is still running. Example: https://gist.github.com/819348
# - Check for dependencies.
# - Ramdisk for world files? Is that even needed on a Linux server?
# - Sheduler

# - - - - - - - - - - - -

# Below are the settings you should change to meet the requirements of your own server.

# The name of your screen session. This really doesn't matter to the user. But you should make sure it's set the same as in your launch script.
screen_session_name="mine"

# For the paths below, use absolute paths to be sure the path is correctly found.

# The path and filename of the log file. Choose where you want the log file stored. If you don't want a log file, just set it to /var/tmp/somefile.name.
logfile="$HOME/mc-shell.log"

# Where is your craftbukkit directory? Do not use ~. You may however use $HOME to indicate your home directory.
craftbukkit_path="$HOME/craftbukkit"

# The script file used to start the screen session. Do not use ~. You may however use $HOME to indicate your home directory.
#launch_script="$HOME/craftbukkit/mine"
launch_command="screen -S $screen_session_name -dm java -Xmx2048M -Xms1024M -jar craftbukkit.jar"

# Set the command to launch the console. If you want this to connect to your screen session, just type it below.
# For example "screen -r $screen_session_name". You can use the variables previously set above in this by putting a $ in
# front. Variables are case-sensitive.
# Example for Remote Bukkit: console_start_command="java -jar $HOME/remotebukkitconsole.jar localhost:25564 user pass"
console_start_command="screen -r $screen_session_name"

# A reminder message on how to quit the console. Different consoles have different ways to exit them properly. This is especially important for a screen session.
# You may use \n for a newline, you may also use any other escape sequence including ansi codes.
# Example: console_quit_reminder="REMEMBER:\nIn order to exit your console session, you must press CTRL+a then d."
# Example: console_quit_reminder="Yo dawg. Don't ya fuget to push CTRL+c 2 quit tah console. Ya dig?"
console_quit_reminder="REMEMBER:\nIn order to exit your console session, you must press CTRL+a then d."


# This is not being used because it wasn't always working. Sometimes "version\n" wasn't sent at all until after I attached to the screen session at least once.
function version {
	if screenrunning; then cbver="server not running"; return 1; fi
	screen -S mines -X stuff $'version\n'
	sleep .1 # This because for some reason the version isn't printed before hardcopy is able to copy it or hardcopy has some problem.
	tempfile="/var/tmp/mc-shell-$RANDOM.tmp"
	screen -S "$screen_session_name" -X hardcopy "$tempfile"
	cbver=$(cat "$tempfile" | grep "This server is running CraftBukkit version" -m 1 | cut -f 9 -d' ' | cut -f 3-4 -d'-')
	rm "$tempfile"
	return 0
}

function screenrunning {
	if [ "$(ls /var/run/screen/S-$USER | grep $screen_session_name)" = "$screen_session_name" ]; then
	# Old method of finding screen session.
	#if [ "$(screen -ls | grep "$screen_session_name" | cut -f2 | cut -d. -f2-3)" = "$screen_session_name" ]; then
		echo "$(date +"%m-%d-%Y %r") -: STATUS :- Screen Running Check = TRUE" &>> "$logfile"
		return 1
	else
		echo "$(date +"%m-%d-%Y %r") -: STATUS :- Screen Running Check = FALSE" &>> "$logfile"
		return 0
	fi
}

function stop-server {
	screen -S "$screen_session_name" -p 0 -X stuff $'stop\n' &>> "$logfile"
	if [ $? -ne 0 ]; then
		echo "$(date +"%m-%d-%Y %r") -: ERROR :-  Stopping server failed with exit code $?." &>> "$logfile"
	fi
}

function start-server {
	$launch_command &>> "$logfile"
	if [ $? -ne 0 ]; then
		echo "$(date +"%m-%d-%Y %r") -: ERROR :-  Starting server failed with exit code $?." &>> "$logfile"
	fi
}

echo "$(date +"%m-%d-%Y %r") -: LOGIN :-" &>> "$logfile"
clear
action=""
result_message=""
norm="\033[m"
# I'm not sure why the following two didn't work...
#boldgreen="\033[32;1m"
#boldred="\033[31;1m"
boldyellow="\033[33;1m"
bold="\033[1m"
cd $craftbukkit_path
while :
	do
		serverstatus="\033[31;1mOffline\033[m"
		# Disabled getting version because it didn't always work.
		#version
		screenrunning
		if [ $? -eq 1 ]; then
			serverstatus="\033[32;1mOnline\033[m"
		fi
		clear
		echo -e "\033[36;1mMC-SHELL - Lightweight Remote Server Control$norm"
		echo
		# This should probably be done with printf...
		legend="\
Start/Stop $boldyellow[st]$norm\t\tView Log $boldyellow[log]$norm\t\tConsole $boldyellow[con]$norm\n\
Restart $boldyellow[rs]$norm\t\tShow Errors $boldyellow[err]$norm\tExit $boldyellow[exit]$norm\n\
Update $boldyellow[up]$norm\t\tClear Log $boldyellow[cl]$norm"
		echo -e "$legend"
		echo
		echo -e "\033[1mServer Status:$norm $serverstatus"
		echo -e "\033[34;1m$result_message$norm"
		result_message=
		# Disabled getting version because it didn't always work.
		#echo -e "\033[1mServer Version:$norm \033[34;1m$cbver$norm"
		read -p "> " action
		case $action in
			st)
				# Start it or stop it.
				if screenrunning; then
					echo "$(date +"%m-%d-%Y %r") -: STATUS :- Server started." &>> "$logfile"
					echo "Starting server..."
					start-server
					sleep 20
					result_message="Server was started."
				else
					echo "$(date +"%m-%d-%Y %r") -: STATUS :- Server stopped." &>> "$logfile"
					echo "Stopping server..."
					stop-server
					sleep 10
					result_message="Server was stopped."
				fi
				;;
			rs)
				# Restart it.
				echo "$(date +"%m-%d-%Y %r") -: STATUS :- Server Restarted" &>> "$logfile"
				screenrunning
				if [ $? -eq 1 ]; then
					echo "Stopping server..."
					stop-server
					# Wait 10 seconds for the server to shut down.
					# maybe this should see if the process has closed instead.
					sleep 10
				fi
				screenrunning
				if [ $? -eq 0 ]; then
					echo "Starting server..."
					start-server
					sleep 20
				fi
				result_message="Server was restarted."
				;;
			up)
				# Update server.
				screenrunning
				if [ $? -ne 0 ]; then
					result_message="Please stop the server first."
					continue
				fi

				echo -e "\033[31;1mWARNING\033[m"
				echo "Are you sure you want to update the server? Type \"yes\" lowercase and without quotes to confirm."
				echo "This may render some plugins unuseable. You will have to check them youself."
				read confirm
				if [ "$confirm" == "yes" ]; then
					echo "Updating server..."
					echo "$(date +"%m-%d-%Y %r") -: STATUS :- Update Started" &>> "$logfile"
					rm craftbukkit.jar 2>> "$logfile"
					if [ $? -ne 0 ]; then
						echo "$(date +"%m-%d-%Y %r") -: ERROR :- rm = Failed with exit code $?." &>> "$logfile"
					fi
					wget http://cbukk.it/craftbukkit-beta.jar -O craftbukkit.jar &>> /dev/null
					if [ $? -ne 0 ]; then
						echo "$(date +"%m-%d-%Y %r") -: ERROR :- wget = Failed with exit code $?." &>> "$logfile"
					fi
					result_message="Server was updated."
				fi
				;;
			log)
				# View server.log
				echo "$(date +"%m-%d-%Y %r") -: STATUS :- Log Viewed" &>> "$logfile"
				echo "Press the Q key to quit viewing. Press any key to view..."
				read -n 1 -s
				clear
				cat server.log | less
				if [ $? -ne 0 ]; then
					echo "$(date +"%m-%d-%Y %r") -: ERROR :- View Log = Failed with exit code $?." &>> "$logfile"
				fi
				;;
			con)
				# Use Console.
				echo
				echo -e "$console_quit_reminder"
				echo "Press any key to show console..."
				read -n 1 -s
				clear
				echo "$(date +"%m-%d-%Y %r") -: STATUS :- Console started." &>> "$logfile"
				$console_start_command
				if [ $? -ne 0 ]; then
					echo "$(date +"%m-%d-%Y %r") -: ERROR :- Console = Failed with exit code $?." &>> "$logfile"
				fi
				;;
			err)
				# Show SEVERE errors from log file.
				echo "Press the Q key to quit viewing. Press any key to continue..."
				read -n 1 -s
				clear
				echo "$(date +"%m-%d-%Y %r") -: STATUS :- Showed errors from log." &>> "$logfile"
				cat server.log | grep "SEVERE" | less
				if [ $? -ne 0 ]; then
					echo "$(date +"%m-%d-%Y %r") -: ERROR :- Show Errors = Failed with exit code $?." &>> "$logfile"
				fi
				;;
			cl)
				# Clear Log.
				echo "$(date +"%m-%d-%Y %r") -: STATUS :- Log Cleared" &>> "$logfile"
				rm server.log &>> "$logfile"
				if [ $? -ne 0 ]; then
					echo "$(date +"%m-%d-%Y %r") -: ERROR :- Clear Log = Failed with exit code $?." &>> "$logfile"
				fi
				touch server.log # Make sure the file still exists so there are no complaints from cat or rm in the future.
				result_message="Log Cleared."
				;;
			exit)
				# Exit.
				echo "$(date +"%m-%d-%Y %r") -: LOGOUT :-" &>> "$logfile"
				exit
				;;
			*)
				# Incorrect Input
				result_message="You have incorrectly typed a command. Your command was: \033[35;1m$action"
				;;
	esac
done

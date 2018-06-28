# Set the value of a name=value string in a config file to the 
# specified value.  
# If the file does not exist, or is not writeable, return non-zero status.
#
# usage: set_config_value file name value
#
set_config_value() {
    if [ ! -w "$1" ]    # file doesn't exist or is not writeable
    then
        return 1
    fi
    if grep "^$2\s*[:=]" $1 > /dev/null # if file contains name, edit the value
    then
        sed -i "s|^\($2\s*[:=]\s*\).*$|\1$3|" "$1" 2> /dev/null
    else                    # if it doesn't, append the name/value pair
        echo "$2 = $3" >> "$1"
    fi
}

# Retrieve the configuration value for the given name from the
# given configuration file.  Output the value to stdout.
# If the name does not exist in the config file, or if it has no
# value associated with it, ether output an empty string to stdout, or
# if a default value has been supplied, output that instead.
# If the config file doesn't exist or can't be opened,
# return a non-zero status.
#
# usage: get_config config_file name [default_value]
#
get_config() {
    local val status
    val=`sed -n "s|^$2\s*[:=]\s*\(.*\S\)\s*$|\1|p" $1 2> /dev/null`
    status=$?
    if [ $status -ne 0 ]
    then
        return $status
    fi
    echo -n ${val:="$3"}
}

# get the original logged in user (because logname and "who am i" don't work)
#
getluser () {
    ps Tuf --no-headers | sed -e '/ .*/s///' -e q
}

# Create a directory owned by root if it does not already exist.
#
# usage create_dir dir...
#
create_dir() {
    for dir in "$@"
    do
        if [ ! -d $dir ]
        then
            mkdir $dir
        fi
        chown root:root $dir
        chmod 755 $dir
    done
}


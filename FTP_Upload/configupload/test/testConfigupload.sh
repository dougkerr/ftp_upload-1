# tell the script under test not to proceed with normal execution
#
UNIT_TEST_IN_PROGRESS=1

. ../configupload.sh

setUp() {
    rm -rf _ttf_*   # remove the temporary test files
}

# test the functions for setting values in config files
#
test_set_config_values() {
    # set up temporary test files

	ttf_orig=_ttf_configvals_orig.conf
    cat > $ttf_orig << 'END_OF_FILE' 
server_name = examle.com
user_name=example_user
value_with_spaces = value with spaces
number1=999
number2 = 9
END_OF_FILE

	ttf_expected=_ttf_configvals_expected.conf
    cat > $ttf_expected << 'END_OF_FILE' 
server_name = realname.org
user_name=realName
value_with_spaces = new value with spaces
number1=111
number2 = 222
END_OF_FILE
    
    # substitute the values
	set_config_value $ttf_orig server_name realname.org
    set_config_value $ttf_orig user_name realName
	set_config_value $ttf_orig value_with_spaces "new value with spaces"
    set_config_value $ttf_orig number1 111
    set_config_value $ttf_orig number2 222
    
    # check the result
    diff $ttf_expected $ttf_orig
assertEquals "config values set correctly" 0 $?
}


# test the function for returning values from config files
#
test_get_config() {
    ttf_config=_ttf_config.py
    cat > $ttf_config << 'END_OF_FILE'
[default]
cs_name: gooddomain.org
cs_user: theuser
long_one=string with spaces
var_space = wordWithTrailingSpaces   
lastly: string with trailing spaces   
END_OF_FILE

    result=""
    for name in cs_name cs_user long_one var_space lastly
    do
		result="${result}`get_config "$ttf_config" "$name"` "
    done

    expected="\
gooddomain.org \
theuser \
string with spaces \
wordWithTrailingSpaces \
string with trailing spaces "

    assertEquals "get_config results" "$expected" "$result"
}


# test the function to create directories owned by root
# even if they already exist. Note: we're not testing
# for ownership by root so that the tests don't have to
# be run as root
#
test_create_dir() {
    list="_ttf_dir1 _ttf_dir2 _ttf_dir3"

    create_dir $list
    for d in $list
    do
        test -d $d
        assertTrue "directory $d exists" $?
    done
}


. `which shunit2`    

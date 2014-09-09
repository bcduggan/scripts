#!/bin/bash

DEBUG=0
test $DEBUG -eq 1 && set -x

# This script recursively sets access control list settings according to context.
# By default, it will copy the DAC permissions of the file owner user to an ACL for the
# supplied user.
#
# $ ctxacl.sh user dir
#
# The script will always set a default ACL on directories using the copied DAC permissions.
# setfacl will automatically generate ACL masks for every file and directory it creates
# 'group class' ACLs for (the type created by this script). See:
# http://www.novell.com/documentation/suse91/suselinux-adminguide/html/apbs03.html
#
# To copy the group owner DAC permission bits to the given user, 
# $ ctxacl.sh -g user dir
#
# or to the given group,
# $ ctxacl.sh -g :group dir
#
# or to both,
# $ ctxacl.sh -g user:group dir
#

USAGE="$0 [-g] user:group dir"

cpgroup=0
acluser=""
aclgroup=""

while getopts "g" opt; do
    case $opt in
	g)
	    cpgroup=1
	    ;;
	\?)
	    exit 1
	    ;;
	:)
	    exit 1
	    ;;
    esac
done

shift $((OPTIND-1))

# Expect user:group and dir
if [[ $# -ne 2 ]]; then
    echo $USAGE
    exit 1
fi

aclprincipals=$1
acldir=$2

acluser=$(echo $aclprincipals | cut -f 1 -d:)
aclgroup=$(echo $aclprincipals | cut -f 2 -d:)

if [[ -z $acluser && -z $aclgroup ]]; then
    echo $USAGE
    exit 1
fi

# The user wants to copy from either the user owner or the group owner
test $cpgroup -eq 1 && pincipal_type="group" || principal_type="user"

# Reset IFS to cycle through find results
origIFS=$IFS
IFS=$'\n'
for aclfile in $(find $acldir); do
    echo $aclfile

    # And rest IFSagain to keep getfacl output from being on one line
    IFS=$origIFS
    # Like: user::r-x
    dac=$(getfacl $aclfile | grep $principal_type:: | cut -f 3 -d:)
    IFS=$'\n'
   
    rwbits=$(echo $dac | cut -c 1-2)
    xbit=$(echo $dac | cut -c 3)

    # If a directory,
    if [[ -d $aclfile ]]; then
	# always set the x bit,
	aclbits=$rwbits"x"
	# and set a default ACL using the directory's rw bits.
	test -n $acluser && setfacl -d -m u:$acluser:$rwbits"x" $aclfile
	test -n $aclgroup && setfacl -d -m g:$aclgroup:$rwbits"x" $aclfile
    else
	# Or copy the non-directory file's rwx bits.
	aclbits=$rwbits$xbit
    fi

    # Finally, set the ACL from the calculate rwx bits.
    test -n $acluser && setfacl -m u:$acluser:$aclbits $aclfile
    test -n $aclgroup && setfacl -m g:$aclgroup:$aclbits $aclfile

done
IFS=$origIFS

test $DEBUG -eq 1 && set +x

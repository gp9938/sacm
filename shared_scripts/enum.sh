#!/bin/bash
ENUM_SH_VERSION="1.0"
#
#
#

#
# Create a bash "enum" as an associative array
#
create_enum() {
    local i=0
    local sort='n'
    if [ $# -gt 0 -a ${1} = '-sort' ]; then
	sort='y'
	shift
    fi

    if [ $# -gt 0 ]; then
	local enum_name=${1}
	shift
    fi
    
    declare -Ag ${enum_name}

    if [ ${sort} = 'y' ]; then
	local enum_items=( $(tr ' ' '\n' <<<${@} | sort) )
	set -- "${enum_items[@]}"
    fi
    
    while [[ $# -gt 0 ]]; do
	eval ${enum_name}["${1}"]="${i}"
	eval ${enum_name}["${i}"]="${1}"
	shift 
	((i++))
    done
    readonly ${enum_name}
}

check_valid_enum_elem() {
    if [ $# -ne 2 ]; then
	return 1;
    fi
    local -n enum_name=${1}
    local elem_name=${2}

    
    if [[ -v enum_name[${elem_name}] ]]; then
	echo 1
	return 0
    else
	echo 0
	return 1
    fi
}

#
# Print the bash enum as an associative arrayt
#
print_enum() {
    local readonly number_regex='^[0-9]+$'

    local sort='n'
    if [ $# -gt 0 -a ${1} = '-sort' ]; then
	sort='y'
	shift
    fi

    if [ $# -gt 0 ]; then
	local -n enum_name=${1}
    else
	echo "Nothing to print"
	return 1
    fi

    local key_list
    if [ ${sort} = 'y' ]; then
	key_list=( $(tr ' ' '\n' <<<${!enum_name[@]} | sort ) )
    else
	key_list=( ${!enum_name[@]} )
    fi
    
    for key in ${key_list[@]}; do
	if [[ ! ${key} =~ ${number_regex} ]]; then
	    echo -e "${key}="${enum_name[${key}]}
	fi
    done
    
}


print_unsorted_enum() {
    local -n enum_name=${1}
    local readonly number_regex='^[0-9]+$'
    
    for key in ${!enum_name[@]}; do
	if [[ ! ${key} =~ ${number_regex} ]]; then
	    echo -e "${key}:\t" ${enum_name[${key}]}
	fi
    done
    
}


test_enum() {
    echo "create enum unsorted"
    create_enum FRUIT01 PLUM GRAPE ORANGE APPLE
    echo -n "check positional argument: "
    if [ ${FRUIT01[PLUM]} -eq 0 ]; then echo PASS;  else echo FAIL; fi
    echo -n "check positional argument: "
    if [ ${FRUIT01[APPLE]} -eq 3 ]; then echo PASS;  else echo FAIL; fi
    
    echo "create enum sorted"
    create_enum -sort FRUIT02 PLUM GRAPE ORANGE APPLE
    echo -n "check positional argument: "
    if [ ${FRUIT02[PLUM]} -eq 3 ]; then echo PASS;  else echo FAIL; fi
    echo -n "check positional argument: "
    if [ ${FRUIT02[APPLE]} -eq 0 ]; then echo PASS;  else echo FAIL; fi


    local result
    local expected_result
    # print unsorted enum FRUIT01 unsorted
    expected_result=$(echo -e "GRAPE=1\nPLUM=0\nAPPLE=3\nORANGE=2\n")
    # to print a result with newlines use cat <<<${result}
    result=$(print_enum FRUIT01)
    echo -n "check print unsorted enum: "
    if [ "${result}" = "${expected_result}" ]; then echo PASS; else echo FAIL; fi

    expected_result=$(echo -e "APPLE=3\nGRAPE=1\nORANGE=2\nPLUM=0\n")
    # to print a result with newlines use cat <<<${result}
    result=$(print_enum -sort FRUIT01)
    echo -n "check print sorted enum: "
    if [ "${result}" = "${expected_result}" ]; then echo PASS; else echo FAIL; fi

    echo -n "call check_valid_enum_elem for enum does not exist:"
    if check_valid_enum_elem XXX XXX; then echo FAIL; else echo PASS; fi

    echo -n "call check_valid_enum_elem for enum exists but elem does not exist:"
    if check_valid_enum_elem FRUIT01 XXX; then echo FAIL; else echo PASS; fi

    echo -n "call check_valid_enum_elem for enum exists and elem exists:"
    if check_valid_enum_elem FRUIT01 PLUM; then echo PASS; else echo FAIL; fi
   
}

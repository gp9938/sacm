#!/bin/bash

argfunction() {
    echo argfunction received $# args
    echo ${@}
    tr ' ' '\n' <<<${@} | sort
    shift
    echo argfunction now has $# args
}

DATE='12-34-5678' # set to sample value
NUMBER='a'

kREGEX_DATE='^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$' # note use of [0-9] to avoid \d
if [[ ${DATE} =~ $kREGEX_DATE ]]; then
    echo "regex true"
else
    echo "regex false"
fi

kNUMBER='^[0-9]+'
if [[ ${NUMBER} =~ ${kNUMBER} ]]; then
    echo "number regex true"
else
    echo "number regex false"
fi

#echo $? # 0 with the sample value, i.e., a successful match

argfunction bar ace zoo pipe moose moon car

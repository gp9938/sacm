#!/bin/bash
#
# Sort diffs into four buckets:
#               unchanged lines
#               moved lines
#               deleted  lines
#               added lines
#
# Licenced under GPL3 -- a license is provided in this softwares repository
#
#
usage() {
    cat <<EOF
    usage $0 -[-o <outfiles-prefix>] [--ln-width <decimal-width] [--ln-del <delimiter>] <file1> <file2>

    Will output diff lines lines into four files based on whether the lines are unchanged, moved,
    deleted, or added.

    <outfiles-prefix> is a path + name to prefix output files with (e.g. /var/tmp/out, /tmp/mydiffs)
        These files are suffixed with _unc.txt _mov.txt _del.txt _add.txt.  "${DEFAULT_OUT_PFX}" is
	the default.

    --ln-width controls the decimal width of the line number. ${DEFAULT_LN_WIDTH} is the default.
    --ln-del controls if the line number is followed by a delimiter.   The default is colon (:). To
             suppress the delimiter, provide value "none"
        
EOF
}

output_line() {
    local line=${1}
    local plain_line=${2}
    local outfile=${3}

    echo ${line:1} >> ${outfile}
}


OUT_SFX_UNC="_unc.txt"
OUT_SFX_MOV="_mov.txt"
OUT_SFX_DEL="_del.txt"
OUT_SFX_ADD="_add.txt"

DEFAULT_LN_WIDTH="6"
DEFAULT_OUT_PFX="./out"

if [ $# -lt 2 ]; then
    echo Incorrect number of arguments $#
    usage
    exit 1
fi

POSITIONAL_ARGS=()

LN_DEL=":"
LN_WIDTH=${DEFAULT_LN_WIDTH}

while [[ $# -gt 0 ]]; do
    case $1 in
	-o|--outfiles_prefix)
	    OUTFILES_PREFIX="$2"
	    shift # past argument
	    shift # past value
	    ;;
	-lnw|--ln-width)
	    LN_WIDTH="$2"
	    if ! [[ ${LN_WIDTH}=~"^[0-9]+$" ]]; then
		echo "ln-width of \"${LN_WIDTH}\" is not a number.  Exiting..."
		exit 1
	    fi
	    shift # past argument
	    shift # past value
	    ;;
	-lnd|--ln-del)
	    LN_DEL="$2"
	    if [ ${LN_DEL} = "none" ]; then
		LN_DEL=""
	    elif [ ${#LN_DEL} -ne 1 ]; then
		echo "ln-del of \"${LN_DEL}\" must be one character.  Exiting..."
		exit 1
	    fi
	    shift # past argument
	    shift # past value
	    ;;
	-*|--*)
	    echo "Unknown option $1"
	    usage
	    exit 1
	    ;;
	*)
	    POSITIONAL_ARGS+=("$1") # save positional arg
	    shift # past argument
	    ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

file1=$1
file2=$2

outfile_unc="${DEFAULT_OUT_PFX}${OUT_SFX_UNC}"
outfile_mov="${DEFAULT_OUT_PFX}${OUT_SFX_MOV}"
outfile_del="${DEFAULT_OUT_PFX}${OUT_SFX_DEL}"
outfile_add="${DEFAULT_OUT_PFX}${OUT_SFX_ADD}"

>${outfile_unc}
>${outfile_mov}
>${outfile_del}
>${outfile_add}

base_fmt="%0${LN_WIDTH}dn${LN_DEL}%L"
unc_ln_fmt="u${base_fmt}"
old_ln_fmt="d${base_fmt}"
new_ln_fmt="a${base_fmt}"
plain_line_offset=$(expr ${LN_WIDTH} + 3)
grep_offset=$(expr ${LN_WIDTH} + 2)

#set -x
diff_out=$(diff --unchanged-line-format="${unc_ln_fmt}" --old-line-format="${old_ln_fmt}" \
		--new-line-format="${new_ln_fmt}" ${file1} ${file2})


while IFS= read -r line; do
    echo ${line}
done <<<${diff_out}

echo ""

while IFS= read -r line; do
    
    plain_line=${line:${plain_line_offset}}

    set -x
    case ${line:0:1} in
	d) # deleted line, check if was added
	    num_deleted=$(grep -Exc "^d.{${grep_offset}}${plain_line}" <<<${diff_out})
	    num_added=$(grep -Exc "^a.{${grep_offset}}${plain_line}" <<<${diff_out})
	    echo num_deleted of ${plain_line}: ${num_deleted}
	    echo num_added of ${plain_line}: ${num_added}
	    if [ ${num_deleted} -eq ${num_added} ]; then
		output_line "${line}" "${plain_line}" "${outfile_mov}"
	    else
		output_line "${line}" "${plain_line}" "${outfile_del}"
	    fi									       
	;;
	a) # added line, check if deleted, but DO NOT ADD to move file (will happen above)
	    num_added=$(grep -Exc "^a.{${grep_offset}}${plain_line}" <<<${diff_out})
	    num_deleted=$(grep -Exc "^d.{${grep_offset}}${plain_line}" <<<${diff_out})
	    echo num_added of ${plain_line}: ${num_added}
	    echo num_deleted of ${plain_line}: ${num_deleted}
	    if [ ${num_deleted} -eq ${num_added} ]; then
		echo skipping moved added line
	    else
		output_line "${line}" "${plain_line}" "${outfile_add}"
	    fi									       	    
	;;
	u) # unchanged line
	    output_line "${line}" "${plain_line}" "${outfile_unc}"
	;;
	*)
	    echo Internal error in case line
	;;
    esac
	    
done <<<${diff_out}
    

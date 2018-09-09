#!/usr/bin/env bash

# here's what a file looks like:
#
# first line is the header, with field names separated by tabs:
#
# Class	Number	CW	First Name	Last Name	Car Model	Car Color	Class 2	Grid #	Barcode	Member	Member #	Expires	DOB	Age	Registered	Reg.CheckIn	OLR	Paid	Fee Type	Amnt.	Method	Annual Tech	Annual Waiver	Rookie	Run Heat	Work Heat	Work Assignment	Checkin	Year	Car Make	Gender	Raw Time	Raw Pos.	Prev. Pos.	Total	Diff.	From 1st	Pax Time	Pax Pos.	Best Run	Run 1	Pen 1	Run 2	Pen 2	Run 3	Pen 3	Run 4	Pen 4
#
# each subsequent line is a results entry, with (potentially empty) field
#   values separated by tabs
#

# assumes variables fields, fieldmap variables are set
# when called...
# values are \x01-delimited on standard input
#
#    emit_record <examine-mode> [extra ... ] <<<value1\x01value2\x01...
function emit_record()
{
    declare i=
    declare exwhite='    '
    declare exline=$'\n'$'#'

    (( ! $1 )) && exwhite= && exline=
    shift

    declare record=
    # prepend "extras"
    for i in "$@"
    do
        [[ -n $i ]] && record+=${exwhite}${i}','${exline}
    done

    declare -a values=( )
    IFS=$'\x01' read -r -a values

    for ((i=0; i<${#fields[*]}; i++))
    do
        declare mapentry=${fieldmap[${fields[i]}]}
        [[ -z ${mapentry} ]] && continue; # skip if absent

        declare field=${mapentry%:*}
        declare format=${mapentry#*:}
        declare value=${values[i]}

        # this sucks...  TODO: consider using a real language (i.e. not bash)
        if [[ ${format} == '%d' || ${format} == '%f' ]]
        then
            value=${value//$'['/} # some results look like "[-]0.368"
            value=${value//$']'/} # trim the brackets

            [[ ! ${values[i]} =~ [+-]?[0-9]+(.[0-9]+)? ]] && value=
        fi

        [[ ${format} == '%s,,' ]] && format=%s && value=${value,,}
        [[ ${format} == '%s^^' ]] && format=%s && value=${value^^}

        [[ ${format} == '%s' ]] && format='"%s"'

        printf -v value "${format}" "${value}" || exit $?

        record+="${exwhite}"'"'"${field}"'":'"${value}"','"${exline}"
    done
    record=${record%,${exline}} # trim trailing ex linefeed
    record=${record%,}             # trim trailing comma

    printf "${exline}"'{'"${exline}"%s"${exline}"'}
' "${record}"

}

function results_to_json()
{
    declare config=
    declare examine=0
    declare extra=
    declare usage="
Usage: results_to_json [OPTION]...

Convert an autocross results spreadsheet to json.

Options:

 -x          Examine, then exit.  Outputs a sample config file for the input data that
                can be tweaked and passed as an argument to -c.  Each instance of -x
                causes an additional sample record to be emitted.

 -c <FILE>   Config file name.  Config is a bash program that describes how to map
                input field names to output field names and describes what to do
                with each field, e.g. treat as a string, a raw value (i.e. a number) or
                omit entirely.  See the output of -x for more information.

 -j <STR>    Include STR as part of every output record.  Useful for including
                the event's date, for example: -j '{\"date\":\"2018-03-10\"}', in
                conventional yyyy-MM-dd format.

 -h          prints this message and exits

"

    while getopts ":xc:j:h" opt
    do
        case "${opt}" in
            j) extra="${OPTARG}";;
            x) ((examine++));;
            c) config="${OPTARG}";;
            h) printf %s "${usage}"; exit 0;;
            [?]) printf 'unknown option \"-'%s'\"\n' "${OPTARG}"; exit 1;;
        esac
    done
    ((OPTIND--))
    shift ${OPTIND}

    declare infile=
    for infile in "$@"
    do
        declare infd=

        exec {infd}<${infile} || exit $?

        declare header=
        # read first line into "header"
        read -r -u ${infd} header || exit $?

        # cleanup... remove carriage returns
        #  and change tabs to \x01 to defeat IFS collapsing
        header=${header//$'\r'/}
        header=${header//$'\t'/$'\x01'}

        declare -a fields=( )
        # parse first line into array "fields", note IFS only applies to read
        IFS=$'\x01' read -r -a fields <<<${header}

        declare -A fieldmap=( )
        # config overrides defaults built above
        if [[ -n ${config} ]]
        then
            . "${config}" || exit $?
        else
            # build default fieldmap, basically the field names are to
            #  be cleaned up, and the values will be strings
            for ((i=0; i < ${#fields[*]}; i++))
            do
                declare field=${fields[i],,} # lower-cased
                field=${field// /_}          # ' ' changed to '_'
                field=${field//./}           # '.' removed
                field=${field//$'#'/num,}    # '#' changed to "num"

                fieldmap[${fields[i]}]=${field}':%s'
            done
        fi

        declare -a lines=( )
        # read rest of file into lines, so I can count 'em
        readarray -t -u ${infd} lines || exit $?
        # close infd
        exec {infd}<&-

        if (( examine ))
        then
            printf '################## fieldmap ####################
## Maps original fields to json fields, and how
##  each field is printed, as a printf format specifier.
##  "%s" just makes a string.  If the field should be a number,
##  omit the quotes.  If the field should be omitted from the output
##  set to the empty string or remove the entry altogether
##
## TODO: more features, like True and False from zero and one?
##
'
            # equivalent to typeset -p fieldmap
            printf 'declare -A fieldmap=(
'
            declare field=
            for field in "${!fieldmap[@]}"
            do
                printf '["%s"]=%s
' "${field}" "${fieldmap[${field}]}"
            done

            printf ')
'

            printf '################## sample json ####################
## how the data would look with config set to %s' "${config:-default}"
            numlines=${examine}
            examine=1
        else
            numlines=${#lines[*]}
        fi

        for ((i=0; i<numlines; i++))
        do
            # delete any carriage returns on the line
            declare line=${lines[i]//$'\r'/}

            # change tabs in the file to non-whitespace to
            #  prevent IFS collapsing
            emit_record "${examine}" '"date":"'"${infile%.tsv}"'"' '"entries":'"${numlines}"'' "${extra}" <<<${line//$'\t'/$'\x01'}
        done
    done

}

if [[ ${0} == ${BASH_SOURCE[0]} ]]
then
    results_to_json "$@"
fi

#!/bin/bash

# here's what a file looks like:
#
# first line is the header, with field names separated by tabs:
#
# Class	Number	CW	First Name	Last Name	Car Model	Car Color	Class 2	Grid #	Barcode	Member	Member #	Expires	DOB	Age	Registered	Reg.CheckIn	OLR	Paid	Fee Type	Amnt.	Method	Annual Tech	Annual Waiver	Rookie	Run Heat	Work Heat	Work Assignment	Checkin	Year	Car Make	Gender	Raw Time	Raw Pos.	Prev. Pos.	Total	Diff.	From 1st	Pax Time	Pax Pos.	Best Run	Run 1	Pen 1	Run 2	Pen 2	Run 3	Pen 3	Run 4	Pen 4
#
# each subsequent line is a results entry, with (potentially empty) field
#   values separated by tabs
#

function results_to_json()
{
    declare config=
    declare examine=0
    declare extra=
    declare NaN=
    declare -a inputs=( )
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

 -i <FILE>   Input file name, or \"-\" to indicate standard input (the default).
                Multiple input files may be specified, each with -i.

 -o <FILE>   Output file name, or \"-\" to indicate standard output
                (the default).

 -j <STR>    Include STR as part of every output record.  Useful for including
                the event's date, for example: -j '{\"date\":\"2018-03-10\"}', in
                conventional yyyy-MM-dd format.

 -h          prints this message

"

    while getopts ":xc:i:o:h" opt
    do
        case "${opt}" in
            j) extra="${OPTARG}";;
            i) inputs=( "${inputs[@]}" "${OPTARG}");;
            o) output="${OPTARG}";;
            x) ((examine++));;
            c) config="${OPTARG}";;
            h) printf %s "${usage}";;
            [?]) printf 'unknown option \"-'%s'\"\n' "${OPTARG}"; exit 1;;
        esac
    done
    ((OPTIND--))
    shift ${OPTIND}

    [[ -n ${extra} ]] && extra+=,

    # delete any carriage returns
    tr -d $'\r' |
        # change tabs in the file to non-whitespace to prevent IFS collapsing
        tr $'\t' $'\x01' | (
        declare -a fields=( )
        declare -a values=( )
        declare -A fieldmap=( )

        # read first line into array "fields", note IFS only applies to read
        IFS=$'\x01' read -a fields

        # build default fieldmap, basically the field names are to
        #  be cleaned up, and the values will be strings
        for ((i=0; i < ${#fields[*]}; i++))
        do
            declare field=${fields[i],,} # lower-cased
            field=${field// /_}          # ' ' changed to '_'
            field=${field//./}           # '.' removed
            field=${field//$'#'/num,}    # '#' changed to "num"

            fieldmap[${fields[i]}]=${field}':\"%s\"'
        done

        # config overrides defaults built above
        if [[ -n ${config} ]]
        then
            . "${config}" || exit $?
        fi

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
            declare field
            for field in "${!fieldmap[@]}"
            do
                printf '["%s"]=%s
' "${field}" "${fieldmap[${field}]}"
            done

            printf ')
'

            printf '################## sample json ####################
## how the data would look by default
'
            while (( examine-- ))
            do
                declare record=
                [[ -n ${extra} ]] && record+='   '"${extra}"'
'
                IFS=$'\x01' read -a values
                # echo ${#fields[*]} fields, ${#values[*]} values
                # prepend "extra" to each record
                for ((i=0; i < ${#fields[*]}; i++))
                do
                    declare mapentry=${fieldmap[${fields[i]}]}
                    [[ -z ${mapentry} ]] && continue; # skip if absent

                    declare field=${mapentry%:*}
                    declare format=${mapentry#*:}
                    declare value=${values[i]}

                    if [[ ${format} == '%d' || ${format} == '%f' ]]
                    then
                        value=${value//$'['/}
                        value=${value//$']'/}
                        value=${value#+*}

                        [[ ! ${values[i]} =~ -?[0-9]+(.[0-9]+)? ]] && value=
                    fi

                    printf -v value "${format}" "${value}" || exit $?

                    record+='   "'"${field}"'":'"${value}"',
'
                done
                record=${record%,$'\n'}
                printf '# {
#%s
# }
'  "${record//$'\n'/$'\n'$'#'}"
            done

        else
            # read subsequent lines into array values
            while IFS=$'\x01' read -a values
            do
                declare record=

                for ((i=0; i < ${#fields[*]}; i++))
                do
                    declare mapentry=${fieldmap[${fields[i]}]}
                    [[ -z ${mapentry} ]] && continue; # skip if absent

                    declare field=${mapentry%:*}
                    declare format=${mapentry#*:}
                    declare value=${values[i]}

                    # cleanup for numbers
                    if [[ ${format} == '%d' || ${format} == '%f' ]]
                    then
                        value=${value//$'['/}
                        value=${value//$']'/}
                        value=${value#+*}

                        [[ ! ${values[i]} =~ -?[0-9]+(.[0-9]+)? ]] && value=
                    fi

                    printf -v value "${format}" "${value}" || exit $?

                    record+='"'"${field}"'":'"${value}"','
                done

                # prepend "extra" to each record
                printf "{%s%s}\n" "${extra}" "${record%,}"
            done
        fi
    )
}

if [[ ${0} == ${BASH_SOURCE[0]} ]]
then
    results_to_json "$@"
fi

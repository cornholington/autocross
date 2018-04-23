#!/bin/bash


function esc()
{
    # defaults
    declare method=GET
    declare url=localhost/9200
    declare -a inputs=( )
    declare output='-'
    declare outfd=1
    declare contenttype=application/json
    declare item=_search

declare usage="
Usage: esc [OPTION]...

Submit Elasticsearch command(s).

Options:

 -u <URL>    Host and port of your Elasticsearch node, defaults
                to \"${url}\".

 -n <ITEM>   The path to the Elasticsearch item, defaults to \"${item}\".

 -m <METHOD> Method to use, defaults to \"${method}\"

 -i <FILE>   Input file name, line mode.  Files passed with -i are parsed
                as one document per line.

 -0 <FILE>   Null-terminated input file name.  Multiple documents in
                these files are separated by the null character.

 -1 <FILE>   Whole input file. Read input as a single document per file.

 -o <FILE>   Output file name, or \"-\" to indicate standard output
                (the default).

 -t <TYPE>   HTTP Content-Type of the document, defaults to
               \"${contenttype}\"

 -h          prints this message

If more than one document is passed as input, the command is repeated
   for each document.

Input and output file names can be \"-\" to indicate standard input
   or standard output.  If no inputs are specified, the default is
   \" -1 - \", which means \"standard input as whole document\".

"

    while getopts ":m:n:u:i:0:1:o:t:h" opt
    do
        case "${opt}" in
            m) method="${OPTARG}";;
            n) item="${OPTARG}";;
            u) url="${OPTARG}";;
            [i01]) inputs=( "${inputs[@]}" "${opt}" "${OPTARG}");;
            o) output="${OPTARG}";;
            t) contenttype="${OPTARG}";;
            v) verbose=1;;
            d) dirs=( "${dirs[@]}" "${OPTARG}");;
            h) printf %s "${usage}";;
            [?]) printf 'unknown option \"-'%s'\"\n' "${OPTARG}"; exit 1;;
        esac
    done
    ((OPTIND--))
    shift ${OPTIND}

    (( ${#inputs[*]} )) || inputs=( 1 - ) # default is "whole stdin"

    if [[ ${output} != '-' ]]
    then
        exec {outfd}>${output} || exit $?
    fi

    declare conn=
    # opening connection...
    exec {conn}<>/dev/tcp/"${url}" || exit ${?}

    for ((i=0; i<${#inputs[*]}; i+=2))
    do
        declare infd=0
        declare -a readargs=( )
        declare inmode=${inputs[i]}
        declare infile=${inputs[i+1]}

        # input mode for this input?
        case "${inmode}" in
            1) readargs=( -N $((2048*1024*1024-1)) );;
            0) readargs=( -d $'\0') ;;
            # implied...   i) readargs=( ) ;;
        esac

        if [[ ${infile} != '-' ]]
        then
            exec {infd}<${infile} || exit $?
        fi

        # for each body...
        while (( 1 ))
        do
            declare body=

            # read next body, line or zero mode, if empty, done unless in whole mode
            read -u ${infd} "${readargs[@]}" body || [[ ${inmode} == 1 ]] || break;

            # only accept empty body once
            inmode=0

            declare request=${method}' '${item}' HTTP/1.1'$'\r''
Host: '${url%%/*}$'\r''
Content-Type: '${contenttype}$'\r''
Content-length: '${#body}$'\r''
'$'\r''
'${body}

            printf %s "${request}" 1>&${conn}

            declare header=
            declare value=
            declare resplen=0

            while IFS=':' read -u ${conn} header value
            do
                [[ -z ${header//$'\r'/} ]] && break;

                [[ ${header[0],,} == "content-length" ]] && { resplen=${resplen// /}
                                                              resplen=${resplen//$'\t'/}
                                                              resplen=${resplen//$'\r'/}
                }
            done

            declare resp=
            (( resplen )) && read -u ${conn} -N ${resplen} resp

            printf %s "${resp}" 1>&${outfd}
        done

        # close input, we're done with it
        exec {infd}<&-
    done

    # close connection
    exec {conn}<&-


}


if [[ ${0} == ${BASH_SOURCE[0]} ]]
then
    esc "$@"
fi

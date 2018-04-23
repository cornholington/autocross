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

declare extra=${1} # accept "extra", e.g. "date" :
[[ -n ${extra} ]] && extra+=,

# delete any carriage returns
tr -d $'\r' |
    # change tabs in the file to non-whitespace to prevent IFS collapsing
    tr $'\t' $'\1' | (

    # read first line into array "fields", note IFS only applies to read
    IFS=$'\1' read -a fields

    # the field names have to be cleaned up to be json keys
    for ((i=0; i < ${#fields[*]}; i++))
    do
        fields[i]=${fields[i],,}          # lower-cased
        fields[i]=${fields[i]// /_}       # ' ' changed to '_'
        fields[i]=${fields[i]//./}        # '.' removed
        fields[i]=${fields[i]//$'#'/num,} # '#' changed to "num"
    done

    # read subsequent lines into array "fields"
    while IFS=$'\1' read -a values
    do
        declare record=
            # echo ${#fields[*]} fields, ${#values[*]} values
        # prepend "extra" to each record
        for ((i=0; i < ${#fields[*]}; i++))
        do
            declare field=${fields[i]}

            record+='"'"${fields[i]}"'":"'"${values[i]}"'",'
        done
        printf "{%s%s}\n" "${extra}" "${record%,}"
    done


)

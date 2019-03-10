#!/bin/bash

INPUTRC=query.inputrc
while read -e -r -p "last_name [first_name]: " last_name first_name rest;
do
  last_name=${last_name^^}
  first_name=${first_name^^}
  if [[ -n ${first_name} ]]
  then
      jq -Mc '. | select((.last_name | ascii_upcase)=="'"${last_name}"'") | select((.first_name | ascii_upcase)=="'"${first_name}"'")' < results.json
  else
      jq -Mc '. | select((.last_name | ascii_upcase)=="'"${last_name}"'")' < results.json
  fi

done

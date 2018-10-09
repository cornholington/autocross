# autocross

set up empty kibana and elastic search

convert files:
./results_to_json.sh -c unified.cfg 2016-01-16.tsv > 2016-01-16.json

upload files:
./esc.sh -x POST -n autocross/results -i 2016-01-16.json

whack database:
./esc.sh -x DELETE autocross

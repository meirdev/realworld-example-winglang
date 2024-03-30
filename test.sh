cd ./backend
wing it main.w &
cd ..

sleep 10

var=`grep -r lastPort ./backend/target/main.wsim/.state/**/*.json -h | jq '.lastPort'`

APIURL=http://127.0.0.1:$var/api ./tests-api/run-api-tests.sh

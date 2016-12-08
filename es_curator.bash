#!/bin/bash
#######################################################
#    quick and dirty elasticsearch cleanup
#    -Matt B. (IS)
#######################################################

#Characters to ignore for urlencode
urlencode_safe=""

# check for curl
if ! [[ -f /usr/bin/curl ]]
then
    echo "curl bin not found"
    exit 1
fi

# Get a list of local indexes from localhost
function getLocalIndexes() {
    curl -s 'localhost:9200/_cat/indices?v' 2> /dev/null |grep -v ^health | awk {'print $3'}
}

# Get Local Indexes with a date range match
function getLocalIndexesWithDateRange() {
    curl -s 'localhost:9200/_cat/indices?v' 2> /dev/null |grep -v ^health | awk {'print $3'} |egrep "*-[0-9]{4}\.[0-9]{2}\.[0-9]{2}"
}

# Function URLEncode
function urlencode() {
    python -c 'import urllib, sys; print urllib.quote(sys.argv[1], sys.argv[2])' "$1" "$urlencode_safe"
}

# Check if date $1 is older than $2 days ago
# $1= date string to check, $2=days to retain 
function isDateOld() {
   before_date=$(date --date="$2 days ago" +%s)
   ### Replace logstash/beats dots to dashes
   check_date=$(date -d "$(echo $1 | sed 's/\./-/g')" +%s)

# Debug
#   echo "Before Date: $before_date"
#   echo "Check Date: $check_date"
   if [[ $check_date -lt $before_date ]]
   then
       return 1
   else
       return 0
   fi
}

# $1 index name
function deleteIndex() {
#    echo "Deleting $1"
    curl -s -XDELETE "http://localhost:9200/$(urlencode $1)" 2>&1 > /dev/null
}

# Delete old elasticsearch indexes
function deleteOldIndexes() {
    indexes=$(getLocalIndexesWithDateRange)
    for idx in ${indexes[@]}
    do
        idx_date=$(echo $idx |egrep -o '[0-9]{4}\.[0-9]{2}\.[0-9]{2}')
#        echo "IDX Date: $idx_date for IDX: $idx"
#        echo "Days to Retain: $days_to_retain"
        delete_idx=0
        isDateOld $idx_date $days_to_retain
        delete_idx=$?
#        echo "Delete IDX: $delete_idx"
        if [[ $delete_idx -eq 1 ]]
        then
            deleteIndex $idx
        fi
    done
}

### Main
if [[ -z $1 ]]
then
    echo "Usage: ./script <int_days_to_retain>"
    exit 1
elif [[ $1 =~ ^[0-9]+$ ]]
then
    days_to_retain=$1
elif [[ $1 == "list" ]]
then
    getLocalIndexes
    exit 0
else
    echo "Error: non-integer value for days to retain"
    echo "Usage: ./script <int_days_to_retain>"
    exit 1
fi

### Delete the old thingies
deleteOldIndexes

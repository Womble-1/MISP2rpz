#!/bin/bash


##  A script to get domains from MISP , does a little cleaning and load them into bind as an RPZzone. 
## requires that name servers are defined in MISP so that the zone files it generates are valid. 
## Create an API key in MISP for use here.   

echo $(/bin/date --rfc-3339=seconds) "RPZ update script started"


updaterpz(){

echo $(/bin/date --rfc-3339=seconds) "Download for " $zone_name
/usr/bin/curl --insecure -s -o $temp_rpz -H "Authorization: "$misp_key $url_misp; ec=$?


if [ $ec -ne 0 ]; then
    echo $(/bin/date --rfc-3339=seconds) "Curl download from MISP failed"
    echo $(/bin/date --rfc-3339=seconds) "Exit"
    exit $ec
else
    echo $(/bin/date --rfc-3339=seconds) "Download from MISP complete..."
fi
##  Remove any double dot domains.
## for example  sub..domain.tld

sed --in-place 's/\.\.//g' $temp_rpz
echo $(/bin/date --rfc-3339=seconds) " Removing double dot domains  "

## Check for long lines that bind can't handle. 
long_line_count=`awk ' length($1) > 240' $temp_rpz | wc -l`
if [ $long_line_count > 0 ]; then
#clean file
# http://bind-users-forum.2342410.n4.nabble.com/RPZ-zone-load-failure-ran-out-of-space-td4030.html
#

#

    echo $(/bin/date --rfc-3339=seconds) $long_line_count " Long domain(s) found."
    sed --in-place 's/^\(.\{240\}\).*//g' $temp_rpz

else
#nothing to do.
    echo $(/bin/date --rfc-3339=seconds) "No long domains found."
fi
# check the zone file
/usr/sbin/named-checkzone $zone_name $temp_rpz;ec=$? | echo $(/bin/date --rfc-3339=seconds) -

if [ $ec -ne 0 ]; then
    echo $(/bin/date --rfc-3339=seconds) "checkzone failed"
    echo $(/bin/date --rfc-3339=seconds) "Exit"
    exit $ec
else
    echo $(/bin/date --rfc-3339=seconds) "Checkzone" $zone_name " complete..."
    echo $(/bin/date --rfc-3339=seconds) "" $(cat $temp_rpz | wc -l) " records in " $zone_name ""
fi
/bin/cp $temp_rpz $rpz_zonefile
if [ $ec -ne 0 ]; then
    echo $(/bin/date --rfc-3339=seconds) "Zone file copy failed"
    echo $(/bin/date --rfc-3339=seconds) "Exit"
    exit $ec
else
    echo $(/bin/date --rfc-3339=seconds) "Zone file copy complete..."
fi
# reload the zone file.
/usr/sbin/rndc reload $zone_name;ec=$?

if [ $ec -ne 0 ]; then
    echo $(/bin/date --rfc-3339=seconds) "reload failed"
    echo $(/bin/date --rfc-3339=seconds) "Exit"
    exit $ec
else
    echo $(/bin/date --rfc-3339=seconds) "Reload " $zone_name " complete..."
    rm $temp_rpz
fi
}

## Define the variables and MISP query here

#Blocklist  - Malicious
misp_key='myrandonmispAPIkey' #NS1 user
url_misp='https://misp.host/attributes/restSearch/returnFormat:rpz/published:1/to_ids:1/tags:100/enforceWarninglist:true/type:domain||hostname/publish_timestamp:180d'  ## left as an example... you will probably want to change. 
temp_rpz="/tmp/tempRPZ1.rpz"
zone_name="myzone.rpz"
rpz_zonefile="/etc/bind/zones/db.myzone.rpz"
updaterpz

###Repeat this section for addtional queries / sources or zone. 
#Blocklist2 
misp_key='myrandonmispAPIkey' #NS1 user
url_misp='https://misp2.host/attributes/restSearch/returnFormat:rpz/published:1/to_ids:1/tags:200/enforceWarninglist:true/type:domain||hostname/publish_timestamp:60d'
temp_rpz="/tmp/tempRPZ2.rpz"
zone_name="myzone.rpz"
rpz_zonefile="/etc/bind/zones/db.myzone.rpz"
updaterpz


exit 0

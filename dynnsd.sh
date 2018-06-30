#!/usr/bin/env sh

## dynnsd.sh
# Update the NS records of a NSD server

# Copyright 2018 Christian Baer
# http://github.com/chrisb86/

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Set some defaults
CONF_DIR="/usr/local/etc/dynnsd.d"
LAST_IP="none"
LAST_IP6="none"
TTL=3600

# Update the serial of a zone file
main_zone_update_serial() {
  # Code found at https://forums.freebsd.org/threads/increment-number-of-a-dns-zone.2654/. Written by DutchDaemon.
  ZONE=$1

  # get serial number
  SERIAL=$(grep -e "2[0-9]\{3\}[0-1]\{1\}[0-9]\{1\}[0-3]\{1\}[0-9]\{1\}[0-9]\{2\}" ${ZONE} | awk '{print $1}')

  # get serial number's date and number
  SERIAL_DATE=$(echo ${SERIAL} | cut -b 1-8)
  SERIAL_NUMBER=$(echo ${SERIAL} | cut -b 9-10)

    # get today's date in same style
  DATE_TODAY=$(date +%Y%m%d)

  # compare date and serial date
  if [ "${SERIAL_DATE}" = "${DATE_TODAY}" ]
    then
      # if equal, just add 1
      # if equal and number equal 99, do not change
      if [ ${SERIAL_NUMBER} -ge 99 ]; then
        NEWSERIAL=${SERIAL}
      else
        # increment serial number
        NEWSERIAL_NUMBER=$(expr $SERIAL_NUMBER + 1)
        # if < 10, add a 0 to have 2 digits
        if [ ${NEWSERIAL_NUMBER} -le 9 ]; then
          NEWSERIAL_NUMBER="0"${NEWSERIAL_NUMBER}
        fi
        # construct new serial
        NEWSERIAL=${SERIAL_DATE}${NEWSERIAL_NUMBER}
      fi
    else
      # if not equal, make a new one and add 00
      NEWSERIAL=$(echo ${DATE_TODAY}"01")
    fi

    # write the new serial
    /usr/bin/sed -i -e "s/${SERIAL}/${NEWSERIAL}/g" ${ZONE}
}

## Make the magic happen
cd $CONF_DIR

# Loop through configs
for f in *.conf
do
  # Reset changes toggle
  HAS_CHANGES=FALSE
  . $f

  # Files to store the last IPs
  LAST_IP_FILE=".lastip.$SUBDOMAIN"
  LAST_IP6_FILE=".lastip6.$SUBDOMAIN"

  ## IPv4
  if [ -n "$UPDATE" ]; then

    # Scan log file for requests
  	REQ_IP=$(grep ${UPDATE} ${LOG} | grep ${PASS} | tail -1 | awk '{print $2}')

    # Get the last stored IP if there's one
  	if [ -f $LAST_IP_FILE ]; then
  	  LAST_IP=$(cat $LAST_IP_FILE)

  	fi

    # If IP has changed, store the new IP
  	if [ $LAST_IP != $REQ_IP ]; then
  	  echo $REQ_IP > $LAST_IP_FILE
      $REQ_IP=$LAST_IP
  	  HAS_CHANGES=TRUE
      RELOAD_NSD=TRUE
  	fi
  fi

  ## IPv6
  if [ -n "$UPDATE6" ]; then

    # Scan log file for requests
  	REQ_IP6=$(grep ${UPDATE6} ${LOG} | grep ${PASS} | tail -1 | awk '{print $2}')

    # Get the last stored IP if there's one
  	if [ -f $LAST_IP6_FILE ]; then
  	  LAST_IP6=$(cat $LAST_IP6_FILE)
  	fi

    # If IP has changed, store the new IP
  	if [ $LAST_IP6 != $REQ_IP6 ]; then
  	  echo $REQ_IP6 > $LAST_IP6_FILE
      $REQ_IP6=$LAST_IP6
  	  HAS_CHANGES=TRUE
      RELOAD_NSD=TRUE
  	fi
  fi

  # Write IPs to temporary zone file and move it to actual zone file
  echo "$SUBDOMAIN $TTL IN AAAA $LAST_IP6" >> $ZONEFILE.tmp
  echo "$SUBDOMAIN $TTL IN A $LAST_IP" >> $ZONEFILE.tmp
  mv $ZONEFILE.tmp $ZONEFILE

  # If IPs have changed, update main zone file
  if [ -n "$HAS_CHANGES" ]; then
  	main_zone_update_serial $MAIN_ZONEFILE
  fi

done

# If zones have changes, reload nsd and notify slaves
if [ -n "$RELOAD_NSD" ]; then
	nsd-control reload
	nsd-control notify
fi

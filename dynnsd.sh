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
LAST_IP_FILE=.lastip.$SUBDOMAIN
LAST_IP6_FILE=.lastip6.$SUBDOMAIN
TTL=3600

cd $CONF_DIR

# Loop through configs
for f in *.conf
do
  . $f

  ## IPv4
  if [ -n "$UPDATE" ]; then

  	REQ_IP=$(grep ${UPDATE} ${LOG} | grep ${PASS} | tail -1 | awk '{print $2}')

  	if [ -f $LAST_IP_FILE ]; then
  	  LAST_IP=$(cat $LAST_IP_FILE)

  	fi

  	if [ $LAST_IP != $REQ_IP ]; then
  	  echo $REQ_IP > $LAST_IP_FILE
      $REQ_IP=$LAST_IP
  	  HAS_CHANGES=TRUE
  	fi
  fi

  ## IPv6
  if [ -n "$UPDATE6" ]; then

  	REQ_IP6=$(grep ${UPDATE6} ${LOG} | grep ${PASS} | tail -1 | awk '{print $2}')

  	if [ -f $LAST_IP6_FILE ]; then
  	  LAST_IP6=$(cat $LAST_IP6_FILE)
  	fi

  	if [ $LAST_IP6 != $REQ_IP6 ]; then
  	  echo $REQ_IP6 > $LAST_IP6_FILE
      $REQ_IP6=$LAST_IP6
  	  HAS_CHANGES=TRUE
  	fi
  fi

  echo "$SUBDOMAIN $TTL IN AAAA $LAST_IP6" >> $ZONEFILE.tmp
  echo "$SUBDOMAIN $TTL IN A $LAST_IP" >> $ZONEFILE.tmp
  mv $ZONEFILE.tmp $ZONEFILE

done

if [ -n "$HAS_CHANGES" ]; then
	nsd-control reload
	nsd-control notify
fi

# dynnsd.sh - DDNS with NDS

dynnsd.sh is a small shell script that monitors the access logs of your webserver to update NS records of configured domains in NSD.

It's based on the works of [Mike J. Savage](https://mikejsavage.co.uk/blog/least-effort-dyndns.html) and [Michael Clemens](https://github.com/exitnode/nsd-dyndns).

## Preparing your nameserver

dynnsd.sh requires an NSD name server that is configured to serve your zone (e.g. example.com). It relies on nsd-control that must be configured too. It needs reading access to your logfile an write access to the folder for your dynamic zone files.

The few other used tools (awk, grep, cat, cron) should be system independend. Your dynamic host should give you the possibility to run cron jobs and access a web site (e.g. with curl).

### /usr/local/etc/nsd/nsd.conf
Nothing special here.
```
remote-control:
        control-enable: yes

zone:
        name: example.com
        zonefile: /usr/local/etc/nsd/zones/example.com
```
### /usr/local/etc/nsd/zones/example.com
This is a pretty standard zone file. It serves example.com and the hosts that we need to update the NS records. In the last line we include the zone file for the dynamic host. In the script we call it _$MAIN_ZONEFILE_.
```
; example.com
$ORIGIN example.com.
$TTL 3600
@                       IN      SOA     ns1.dblx.io. hostmaster.dblx.io. (
                        2018060301              ; Serial number
                        10800                   ; Refresh
                        3600                    ; Retry
                        604800                  ; Expire
                        86400)                  ; Minimum TTL

                        ; Nameserver definition
                        IN      NS      ns1.dblx.io.
                        IN      NS      ns2.dblx.io.

                        ; Mail exchanger definition
                        IN      MX      10      mail.dblx.io.

; A records definition
@                 300     IN      A      192.168.178.23
update	       		300	    IN	    A	     192.168.178.23
4.update			    300	    IN	    A	     192.168.178.23

; AAAA records definition
@                 300     IN      AAAA   fe80:4000:35:11d::14
update			      300	    IN      AAAA   fe80:4000:35:11d::14
6.update			    300	    IN      AAAA   fe80:4000:35:11d::14

; CNAME records
www 300 CNAME @

$INCLUDE /usr/local/etc/nsd/zones/dyn/dyn.example.com
```
### /usr/local/etc/nsd/zones/dyn/dyn.example.com
This is the zone file that will automagically be created by dynnsd.sh. Nothing to do here.
```
dyn.example.com 300 IN A 10.0.10.71
dyn.example.com 300 IN AAAA fe80:23:185:12::191
```
## Configuring your web server
Your webserver has to be configured to server 2 domains. One of them has to be IPv6 only and the other one has to be IPv4 only. Both virtual servers has to be logged to the same logfile.

In nginx we have to define a new log_format that includes the queried host name.

### /usr/local/etc/nginx.conf
```
http {
    ...
    log_format access '$host $remote_addr - $remote_user [$time_local] '
                               '"$request" $status $body_bytes_sent '
                               '"$http_referer" "$http_user_agent" "$gzip_ratio"';
    ...

    server {
        listen 80;
        listen [::]:80;

        server_name update.example.com update4.example.com update6.example.com;

        root /usr/local/www/update.example.com/www;
        access_log /usr/local/www/update.example.com/logs/nginx.access.log access;

        ...
    }
}
```
We create file to prevent 404 errors.

```
touch /usr/local/www/update.example.com/www/update
```
## dynnsd.sh itself

The script only wants a few small settings in the config file. Point to your web server log and your zone file, tell him the name of the update hosts, set a password and you're done.

### /usr/local/etc/dynnsd.d/dyn.example.com.zone.dist
```
## The domain that you want to update
SUBDOMAIN="dyn.example.com"

## The secret to authenticate you
PASS="gzqtrfqdX8xin7Pg&fdqmne8gyxddasggw+x]W)Urbx{hpbrpW"

## The host to query for updating your NS records
## Uncomment UPDATE6 and put in the URL that can be only resolved via IPv6.
UPDATE="update4.example"
UPDATE6="update6.example.com"

## The logfile of the virtual server that should be monitored
LOG="/usr/local/www/update.example.com/logs/nginx.access.log"

## The zone files that you want to update
ZONEFILE="/usr/local/etc/nsd/zones/dyn/dyn.example.com"
MAIN_ZONEFILE="/usr/local/nsd/zones/example.com.zone"

```

## The cron jobs
Finally we have to define some cron jobs on the host and the server.

I set them to run every minute but you can change this if you want to. The cron job on the server makes the magic happen. The cron job on the client queries the webserver so we can get the IPs from the log file.

### On server
```
*1 * * * * /root/bin/dynnsd.sh
```
### On the dynamic client
```
*1 * * * * curl --silent https://update6.example.com/update.htm?<YOURSECRET> > /dev/null
*1 * * * * curl --silent https://update4.example.com/update?.htm?<YOURSECRET> > /dev/null
```

That's it. Small and handy.

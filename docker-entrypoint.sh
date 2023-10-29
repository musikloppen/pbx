#/bin/sh

perl -pi -e 's/\$SIP_TRUNK_USERNAME/$ENV{SIP_TRUNK_USERNAME}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_TRUNK_SECRET/$ENV{SIP_TRUNK_SECRET}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_TRUNK_HOST/$ENV{SIP_TRUNK_HOST}/g' /etc/asterisk/sip.conf

perl -pi -e 's/\$MYSQL_DATABASE/$ENV{MYSQL_DATABASE}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$MYSQL_USER/$ENV{MYSQL_USER}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$MYSQL_PASSWORD/$ENV{MYSQL_PASSWORD}/g' /etc/asterisk/sip.conf

service asterisk start
service openvpn start

/var/lib/asterisk/notify_user.pl
#while true; do sleep 10; done

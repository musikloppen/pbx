#/bin/sh

perl -pi -e 's/\$SIP_TRUNK_USERNAME/$ENV{SIP_TRUNK_USERNAME}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_TRUNK_SECRET/$ENV{SIP_TRUNK_SECRET}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_TRUNK_HOST/$ENV{SIP_TRUNK_HOST}/g' /etc/asterisk/sip.conf

service asterisk start
service openvpn start

/var/lib/asterisk/notify_user.pl
#while true; do sleep 10; done

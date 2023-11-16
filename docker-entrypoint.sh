#/bin/sh

perl -pi -e 's/\$SIP_TRUNK_USERNAME/$ENV{SIP_TRUNK_USERNAME}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_TRUNK_SECRET/$ENV{SIP_TRUNK_SECRET}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_TRUNK_HOST/$ENV{SIP_TRUNK_HOST}/g' /etc/asterisk/sip.conf

perl -pi -e 's/\$MYSQL_DATABASE/$ENV{MYSQL_DATABASE}/g' /var/lib/asterisk/allowed_caller_id.pl
perl -pi -e 's/\$MYSQL_USER/$ENV{MYSQL_USER}/g' /var/lib/asterisk/allowed_caller_id.pl
perl -pi -e 's/\$MYSQL_PASSWORD/$ENV{MYSQL_PASSWORD}/g' /var/lib/asterisk/allowed_caller_id.pl

perl -pi -e 's/\$MYSQL_DATABASE/$ENV{MYSQL_DATABASE}/g' /var/lib/asterisk/log.pl
perl -pi -e 's/\$MYSQL_USER/$ENV{MYSQL_USER}/g' /var/lib/asterisk/log.pl
perl -pi -e 's/\$MYSQL_PASSWORD/$ENV{MYSQL_PASSWORD}/g' /var/lib/asterisk/log.pl

perl -pi -e 's/\$SIP_TRUNK_CALLER_ID/$ENV{SIP_TRUNK_CALLER_ID}/g' /var/lib/asterisk/gate1.call
perl -pi -e 's/\$GATE_1_PHONE/$ENV{GATE_1_PHONE}/g' /var/lib/asterisk/gate1.call

perl -pi -e 's/\$SIP_TRUNK_CALLER_ID/$ENV{SIP_TRUNK_CALLER_ID}/g' /var/lib/asterisk/gate2.call
perl -pi -e 's/\$GATE_2_PHONE/$ENV{GATE_2_PHONE}/g' /var/lib/asterisk/gate2.call

service asterisk start
service openvpn start

/var/lib/asterisk/notify_user.pl
#while true; do sleep 10; done

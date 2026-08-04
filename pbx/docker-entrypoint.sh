#!/bin/sh
set -e

export DEBUG="${DEBUG:-0}"

# List of required environment variables
REQUIRED_VARS="
SIP_TRUNK_USERNAME
SIP_TRUNK_SECRET
SIP_TRUNK_HOST
SIP_TRUNK_CALLER_ID
GATE_1_PHONE
GATE_2_PHONE
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
ASTERISK_AMI_USER
ASTERISK_AMI_PASS
"

# 1. Validate environment variables
MISSING_VARS=0
for var in $REQUIRED_VARS; do
	eval val=\$$var
	if [ -z "$val" ]; then
		echo "[ENTRYPOINT ERROR] Environment variable '$var' is not set!" >&2
		MISSING_VARS=1
	fi
done

if [ "$MISSING_VARS" -eq 1 ]; then
	echo "[ENTRYPOINT ERROR] Refusing to start due to missing environment variables." >&2
	exit 1
fi

echo "[ENTRYPOINT] All required environment variables are set. Applying templates..."

# --- DEBUG TRUNK ISOLATION OVERRIDE ---
if [ "$DEBUG" = "1" ] || [ "$DEBUG" = "true" ]; then
	echo "[ENTRYPOINT DEBUG] DEBUG MODE IS ACTIVE: Neutralizing SIP registration & host to prevent kicking production!"
	export EFFECTIVE_SIP_HOST="127.0.0.1"
	export EFFECTIVE_SIP_REGISTER="; registration disabled in DEBUG mode"
else
	echo "[ENTRYPOINT] PRODUCTION MODE: Enabling full trunk registration to $SIP_TRUNK_HOST"
	export EFFECTIVE_SIP_HOST="$SIP_TRUNK_HOST"
	export EFFECTIVE_SIP_REGISTER="register => $SIP_TRUNK_USERNAME:$SIP_TRUNK_SECRET@$SIP_TRUNK_HOST/$SIP_TRUNK_USERNAME"
fi

# 2. Replace environment variables in Asterisk SIP config
perl -pi -e 's/\$SIP_TRUNK_USERNAME/$ENV{SIP_TRUNK_USERNAME}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_TRUNK_SECRET/$ENV{SIP_TRUNK_SECRET}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_TRUNK_HOST/$ENV{EFFECTIVE_SIP_HOST}/g' /etc/asterisk/sip.conf
perl -pi -e 's/\$SIP_REGISTER_LINE/$ENV{EFFECTIVE_SIP_REGISTER}/g' /etc/asterisk/sip.conf

# 3. Replace environment variables in Asterisk Manager (AMI) config
perl -pi -e 's/\$ASTERISK_AMI_USER/$ENV{ASTERISK_AMI_USER}/g' /etc/asterisk/manager.conf
perl -pi -e 's/\$ASTERISK_AMI_PASS/$ENV{ASTERISK_AMI_PASS}/g' /etc/asterisk/manager.conf

# 4. Replace environment variables in Asterisk Extensions (Dialplan) config
perl -pi -e 's/\$GATE_1_PHONE/$ENV{GATE_1_PHONE}/g' /etc/asterisk/extensions.conf
perl -pi -e 's/\$GATE_2_PHONE/$ENV{GATE_2_PHONE}/g' /etc/asterisk/extensions.conf
perl -pi -e 's/\$DEBUG/$ENV{DEBUG}/g' /etc/asterisk/extensions.conf

# 5. Replace environment variables in Perl scripts
perl -pi -e 's/\$MYSQL_DATABASE/$ENV{MYSQL_DATABASE}/g' /var/lib/asterisk/allowed_caller_id.pl
perl -pi -e 's/\$MYSQL_USER/$ENV{MYSQL_USER}/g' /var/lib/asterisk/allowed_caller_id.pl
perl -pi -e 's/\$MYSQL_PASSWORD/$ENV{MYSQL_PASSWORD}/g' /var/lib/asterisk/allowed_caller_id.pl

perl -pi -e 's/\$MYSQL_DATABASE/$ENV{MYSQL_DATABASE}/g' /var/lib/asterisk/log.pl
perl -pi -e 's/\$MYSQL_USER/$ENV{MYSQL_USER}/g' /var/lib/asterisk/log.pl
perl -pi -e 's/\$MYSQL_PASSWORD/$ENV{MYSQL_PASSWORD}/g' /var/lib/asterisk/log.pl

# 6. Replace environment variables in Call files
perl -pi -e 's/\$SIP_TRUNK_CALLER_ID/$ENV{SIP_TRUNK_CALLER_ID}/g' /var/lib/asterisk/gate1.call
perl -pi -e 's/\$GATE_1_PHONE/$ENV{GATE_1_PHONE}/g' /var/lib/asterisk/gate1.call

perl -pi -e 's/\$SIP_TRUNK_CALLER_ID/$ENV{SIP_TRUNK_CALLER_ID}/g' /var/lib/asterisk/gate2.call
perl -pi -e 's/\$GATE_2_PHONE/$ENV{GATE_2_PHONE}/g' /var/lib/asterisk/gate2.call

# 7. Start services
echo "[ENTRYPOINT] Starting services..."
service asterisk start

# 8. Run notification daemon script
/var/lib/asterisk/notify_user.pl

# 9. Keep container running in foreground
tail -f /var/log/asterisk/messages /var/log/asterisk/cdr-csv/Master.csv 2>/dev/null || exec tail -f /dev/null

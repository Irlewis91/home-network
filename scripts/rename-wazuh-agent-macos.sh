#!/bin/bash
# Re-enroll this Mac's Wazuh agent under a new name.
set -e
NAME=m3-macbook
CONF=/Library/Ossec/etc/ossec.conf
/Library/Ossec/bin/wazuh-control stop >/dev/null
cp "$CONF" "$CONF.before-rename"
if grep -q "<agent_name>" "$CONF"; then
    perl -0pi -e "s#<agent_name>[^<]*</agent_name>#<agent_name>$NAME</agent_name>#" "$CONF"
elif grep -q "<enrollment>" "$CONF"; then
    perl -0pi -e "s#<enrollment>#<enrollment>\n      <agent_name>$NAME</agent_name>#" "$CONF"
else
    perl -0pi -e "s#(<client>)#\$1\n    <enrollment>\n      <enabled>yes</enabled>\n      <agent_name>$NAME</agent_name>\n    </enrollment>#" "$CONF"
fi
# Forget the old identity so the agent asks the server for a new one.
: > /Library/Ossec/etc/client.keys
grep -E "<address>|<agent_name>|<enrollment>" "$CONF"
/Library/Ossec/bin/wazuh-control start >/dev/null
echo "DONE: agent re-enrolling as $NAME."

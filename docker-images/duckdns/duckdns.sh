
RESPONSE=$(curl -sS --max-time 60 "https://www.duckdns.org/update?domains=${SUBDOMAINS}&token=${TOKEN}&ip=")
if [ "${RESPONSE}" = "OK" ]; then
    echo "Your IP was updated on $(date)"
else
    echo -e "Error updating IP address on $(date)\nThe response returned was:\n${RESPONSE}"
fi

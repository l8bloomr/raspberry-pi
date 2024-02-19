
# Setup default crontab schedule
if [ "$SCHEDULE" = "" ]; then
  SCHEDULE="*/10"
fi

# Configure crontab
echo "# Periodically update Duck DNS with current IP address" > /etc/crontabs/app
if [ "$LOG_FILE" = "true" ]; then
  echo "" >> /var/spool/cron/crontabs/root
  echo "$SCHEDULE * * * * sh -c \"/app/duckdns.sh 2>&1 >> /data/duckdns.log\"" >> /etc/crontabs/app
  echo "0 0 * * * sh -c \"/usr/sbin/logrotate /app/logrotate.conf\"" >> /etc/crontabs/app
else
  echo "$SCHEDULE * * * * sh -c \"/app/duckdns.sh\"" >> /etc/crontabs/app
fi

# Ensure app user has permissions to the data and app directories
chown -R /app /data

# Start crond
crond -f -c /etc/crontabs

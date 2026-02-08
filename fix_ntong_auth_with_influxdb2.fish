#!/usr/bin/env fish

# Authenticate with the admin token
set INFLUX_TOKEN (cat /etc/nixos/secrets/influxdb2.token)

# Get the bucket ID for ntopng
set BUCKET_ID (influx bucket list --org default --name ntopng --token $INFLUX_TOKEN --json 2>/dev/null | jq -r '(. // []) | .[0].id // empty')
if test -z "$BUCKET_ID"
    echo "Error: ntopng bucket not found" >&2
    exit 1
end

# Create v1 auth (username + password -> bucket access) if it doesn't exist
set AUTH_COUNT (influx v1 auth list --token $INFLUX_TOKEN --json 2>/dev/null | jq -r '(. // []) | [.[] | select(.token == "ntopng")] | length')
if test "$AUTH_COUNT" -eq 0
    influx v1 auth create --username ntopng --password (cat /etc/nixos/secrets/ntopng_influxdb2.password) --org default --read-bucket $BUCKET_ID --write-bucket $BUCKET_ID --token $INFLUX_TOKEN
    echo "Created v1 auth for ntopng"
else
    echo "v1 auth for ntopng already exists, skipping"
end

# Create DBRP mapping (database "ntopng" -> bucket "ntopng") if it doesn't exist
set DBRP_COUNT (influx v1 dbrp list --org default --token $INFLUX_TOKEN --json 2>/dev/null | sed '/^VIRTUAL/,$d' | jq -r '(. // []) | [.[] | select(.database == "ntopng")] | length')
if test "$DBRP_COUNT" -eq 0
    influx v1 dbrp create --db ntopng --rp autogen --bucket-id $BUCKET_ID --org default --default --token $INFLUX_TOKEN
    echo "Created DBRP mapping for ntopng"
else
    echo "DBRP mapping for ntopng already exists, skipping"
end

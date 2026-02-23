#!/usr/bin/bash
swaymsg -m -t subscribe '["window"]' | jq --unbuffered 'select(.change == "urgent") | .container.id' | while read id; do
  swaymsg "[con_id=$id] focus"
done

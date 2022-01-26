set sinkIds (pactl list sinks | grep "Sink #" | grep --only-matching --extended-regexp "[0-9]+")
set sinkDescriptions (pactl list sinks | grep "device.description =" | sed "s/.*device.description = //" | sed "s/\"//g")
set APP_ID 41341341
if [ (count $sinkIds) -ne (count $sinkDescriptions) ]
  echo "Parse error: size mismatch of [$sinkIds] and [$sinkDescriptions]"
  exit 1
else
  set selection (echo -e (string join "\n" $sinkDescriptions ) | sort | rofi -dmenu -i -theme /etc/nixos/onedark.rasi -p "Set audio output")
  set n (count $sinkIds)
  set i 1
  while [ $i -le $n ]
    if [ $sinkDescriptions[$i] = $selection ]
      pactl set-default-sink $sinkIds[$i]
      dunstify --urgency low --replace=$APP_ID --appname " " "Audio output set" $selection
      exit 0
    end
    set i (math "$i + 1")
  end
  echo "Internal error"
  exit 1
end
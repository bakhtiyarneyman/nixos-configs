#!/usr/bin/env python3
import sys
import json
import urllib.request
import argparse
import os
from dataclasses import dataclass, asdict
from typing import Optional, List, Dict, Any, NoReturn

# Default port for Elgato Key Light
PORT = 9123

def panic(message: str) -> NoReturn:
    print(message, file=sys.stderr)
    sys.exit(1)

@dataclass
class Light:
    on: Optional[int] = None
    brightness: Optional[int] = None
    temperature: Optional[int] = None

@dataclass
class LightData:
    numberOfLights: int
    lights: List[Light]

def make_url(ip: str) -> str:
    return f"http://{ip}:{PORT}/elgato/lights"

def get_light_data(ip: str) -> LightData:
    url = make_url(ip)
    try:
        with urllib.request.urlopen(url, timeout=2) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                # Parse JSON dicts into dataclasses
                lights = [Light(on=l.get('on'), brightness=l.get('brightness'), temperature=l.get('temperature'))
                          for l in data.get('lights', [])]
                return LightData(numberOfLights=data.get('numberOfLights', 0), lights=lights)
            else:
                panic(f"Error: Received status {response.status} from {ip}")
    except Exception as e:
        panic(f"Error getting status from {ip}: {e}")

def set_light_state(ip: str, on: Optional[bool] = None, brightness: Optional[int] = None) -> Optional[LightData]:
    # Note: The existing keylight script uses PUT, so we use PUT here to match the protocol.
    url = make_url(ip)

    # Use dataclass instead of TypedDict for dot notation support
    light_state = Light()

    if on is not None:
        light_state.on = 1 if on else 0
    if brightness is not None:
        # Key Light expects brightness 0-100 or 3-100 depending on model.
        light_state.brightness = brightness

    # Convert dataclass to dict, filtering out None values for the API payload
    final_light_state: Dict[str, Any] = {k: v for k, v in asdict(light_state).items() if v is not None}

    payload: Dict[str, Any] = {
        "numberOfLights": 1,
        "lights": [final_light_state]
    }

    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=data, method='PUT')
    req.add_header('Content-Type', 'application/json')

    try:
        with urllib.request.urlopen(req, timeout=2) as response:
            if response.status == 200:
                return json.loads(response.read().decode())
    except Exception as e:
        panic(f"Error setting status on {ip}: {e}")

def main() -> None:
    parser = argparse.ArgumentParser(description='Control Elgato Key Light')

    # Target selection
    parser.add_argument('--ip', '-s', help='Specify device IP address')

    # Commands
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--change-brightness-by', type=float, metavar='N', help='Add N to current brightness (or subtract if negative)')
    group.add_argument('--turn-on', action='store_true', help='Turn light on')
    group.add_argument('--turn-off', action='store_true', help='Turn light off')
    group.add_argument('--toggle', action='store_true', help='Toggle light on/off')

    args = parser.parse_args()

    # Determine IP: Priority --ip/-s > env var
    ip = args.ip
    if not ip:
        ip = os.environ.get('KEYLIGHT_IP')

    if not ip:
        panic("Error: No target device specified using --ip/-s or KEYLIGHT_IP.")

    # We fetch current state to handle toggle and relative brightness changes properly
    current_data = get_light_data(ip)
    if not current_data.lights:
        panic(f"Invalid response from {ip}")

    current_light = current_data.lights[0]
    curr_on = current_light.on == 1
    curr_bri = current_light.brightness or 0

    if args.change_brightness_by is not None:
        # Calculate new brightness as int
        new_bri_float = curr_bri + args.change_brightness_by
        new_bri = int(max(0, min(100, new_bri_float)))

        # If brightness > 0, ensure it is on. If 0, turn off.
        should_be_on = True if new_bri > 0 else False
        set_light_state(ip, on=should_be_on, brightness=new_bri)

    elif args.turn_on:
        set_light_state(ip, on=True)

    elif args.turn_off:
        set_light_state(ip, on=False)

    elif args.toggle:
        set_light_state(ip, on=not curr_on)

    else:
        # If no flags provided, just print status
        status = "ON" if curr_on else "OFF"
        print(f"Status: {status}, Brightness: {curr_bri}")

if __name__ == '__main__':
    main()

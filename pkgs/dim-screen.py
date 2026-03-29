#!/usr/bin/env python3

import os, signal, time, argparse, subprocess
from typing import Any
from enum import Enum  # New import

parser = argparse.ArgumentParser(
  description='Dim screen and lock it after some time'
)

parser.add_argument('--dim-seconds', type=int, default=10, help='Time in seconds to dim the screen')
parser.add_argument('--dim-step-seconds', type=float, default=0.025, help='Time in seconds to wait between each step')
parser.add_argument('--min-brightness-percents', type=int, default=1, help='Minimum brightness in percents')
parser.add_argument('--hibernate', action='store_true', help='Invoke `suspend-then-hibernate` on battery discharge, instead of `suspend`')

args = parser.parse_args()

current_notification_id = None

# Declare enum for light commands
class LightCommand(Enum):
    SAVE    = "-O"  # Save brightness
    RESTORE = "-I"  # Restore brightness
    SET     = "-S"  # Set brightness
    GET     = "-G"  # Get brightness


class Brightness:

  @staticmethod
  def get() -> float:
    return float(os.popen(f"light {LightCommand.GET.value}").read())

  @staticmethod
  def set(brightness: float):
    os.system(f"light {LightCommand.SET.value} {brightness}")

  @staticmethod
  def save():
    os.system(f"light {LightCommand.SAVE.value}")

  @staticmethod
  def restore():
    os.system(f"light {LightCommand.RESTORE.value}")

class Notification:
  @staticmethod
  def send(message: str, timeout_ms: int = 0):
      global current_notification_id
      cmd = [
          "notify-send",
          "--print-id",
          "--urgency", "normal",
          "--app-name", "dim-screen"
      ]
      if current_notification_id:
          print(f"Replacing notification id: {current_notification_id}")
          cmd += (["--replace-id", str(current_notification_id)])
      else:
          print(f"First notification")
      if timeout_ms:
          cmd += ["--expire-time", str(timeout_ms)]
      cmd.append("Autolock")
      cmd.append(message)
      try:
          current_notification_id = int(
            subprocess.check_output(cmd, universal_newlines=True).strip()
          )
      except Exception as e:
          print(f"Failed to send notification: {e}")
          current_notification_id = None

  @staticmethod
  def close(message: str):
      Notification.send(message)
      cmd = ["swaync-client", "--close-latest"]
      try:
          subprocess.check_output(cmd, universal_newlines=True)
      except Exception as e:
          print(f"Failed to close notification: {e}")


def restore(sig: signal.Signals, frame: Any):
    print("Restoring brightness...")
    Brightness.restore()
    Notification.close("Restored brightness")
    exit(0)

signal.signal(signal.SIGTERM, restore)
signal.signal(signal.SIGINT, restore)

Brightness.save()
initial_brightness = Brightness.get()
min_brightness = args.min_brightness_percents
total_time = args.dim_seconds

start_time = time.time()
last_notification_time = 0
while True:
  elapsed_time = time.time() - start_time
  remaining_time = total_time - elapsed_time
  if remaining_time <= 0:
    break

  # Cubic curve: drops faster at the start, slower at the end,
  # compensating for logarithmic human brightness perception.
  fraction = remaining_time / total_time
  brightness = min_brightness + (initial_brightness - min_brightness) * fraction ** 3

  Brightness.set(brightness)
  if round(remaining_time) != last_notification_time:
    last_notification_time = round(remaining_time)
    Notification.send(f"Screen will be locked in {last_notification_time} seconds")

  time.sleep(args.dim_step_seconds)

Brightness.set(args.min_brightness_percents)
Notification.close("Screen locked")

if os.system(f"upower --dump | grep 'online.*no'") == 0:
  print("Battery is discharging, invoke suspend")
  if args.hibernate:
    os.system("systemctl suspend-then-hibernate")
  else:
    os.system("systemctl suspend")

signal.pause()

#!/usr/bin/env python3

import os, signal, time, argparse, subprocess
from enum import Enum
from typing import Any

parser = argparse.ArgumentParser(
  description='Dim screen and lock it after some time'
)

parser.add_argument('--dim-seconds', type=int, default=10, help='Time in seconds to dim the screen')
parser.add_argument('--dim-step-seconds', type=float, default=0.025, help='Time in seconds to wait between each step')
parser.add_argument('--min-brightness', type=int, default=1, help='Minimum brightness in native device units')
parser.add_argument('--hibernate', action='store_true', help='Invoke `suspend-then-hibernate` on battery discharge, instead of `suspend`')

args = parser.parse_args()

current_notification_id = None

class BrightnessOption(Enum):
  SAVE = "--save"
  RESTORE = "--restore"


class BrightnessOperation(Enum):
  GET = "get"
  SET = "set"


class Brightness:
  @staticmethod
  def command(
    operation: BrightnessOperation,
    *values: str,
    options: tuple[BrightnessOption, ...] = (),
  ) -> list[str]:
    return [
      "brightnessctl",
      *(option.value for option in options),
      operation.value,
      *values,
    ]

  @staticmethod
  def get(*options: BrightnessOption) -> int:
    return int(subprocess.check_output(
      Brightness.command(BrightnessOperation.GET, options=options),
      text=True,
    ).strip())

  @staticmethod
  def set(brightness: int):
    subprocess.run(Brightness.command(BrightnessOperation.SET, str(brightness)), check=False)

  @staticmethod
  def restore():
    subprocess.run(Brightness.command(BrightnessOperation.GET, options=(BrightnessOption.RESTORE,)), check=False)

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

initial_brightness = Brightness.get(BrightnessOption.SAVE)
min_brightness = args.min_brightness
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
  brightness = round(min_brightness + (initial_brightness - min_brightness) * fraction ** 3)

  Brightness.set(brightness)
  if round(remaining_time) != last_notification_time:
    last_notification_time = round(remaining_time)
    Notification.send(f"Screen will be locked in {last_notification_time} seconds")

  time.sleep(args.dim_step_seconds)

Brightness.set(min_brightness)
Notification.close("Screen locked")

if os.system(f"upower --dump | grep 'online.*no'") == 0:
  print("Battery is discharging, invoke suspend")
  if args.hibernate:
    os.system("systemctl suspend-then-hibernate")
  else:
    os.system("systemctl suspend")

signal.pause()

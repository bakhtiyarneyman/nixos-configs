
{pkgs, dimSeconds ? 10, dimStepSeconds ? 0.05, minBrightnessPercents ? 1}:
let
  light = "${pkgs.light}/bin/light";
  fish = "${pkgs.fish}/bin/fish";
  dimSeconds' = builtins.toString dimSeconds;
  dimStepSeconds' = builtins.toString dimStepSeconds;
  minBrightnessPercents' = builtins.toString minBrightnessPercents;
  battery = "/sys/class/power_supply/BAT1/status";
in pkgs.writeTextFile {
  name = "dim-screen";
  executable = true;
  destination = "/bin/dim-screen";
  text = ''
    #!${pkgs.python3}/bin/python3

    import os, signal, time

    def restore(sig, frame):
      print("Restoring brightness")
      os.system("${light} -I")
      exit(0)

    signal.signal(signal.SIGTERM, restore)
    signal.signal(signal.SIGINT, restore)

    steps = int(${dimSeconds'} / ${dimStepSeconds'})

    os.system('${light} -O') # Save state.
    brightness = float(os.popen('${light}').read()) # Get state.
    step = brightness / steps
    while brightness > ${minBrightnessPercents'}:
      os.system("${light} -S {}".format(brightness))
      brightness -= step
      time.sleep(${dimStepSeconds'})

    os.system('${light} -S {}'.format(${minBrightnessPercents'}))

    if os.path.exists("${battery}") and open("${battery}").read() == "Discharging":
      print("Battery is discharging, invoke suspend")
      os.system("systemctl suspend")

    signal.pause()
  '';
  checkPhase = ''
    ${fish} -n $out
  '';
}

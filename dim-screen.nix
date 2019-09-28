
{pkgs, dimSeconds ? 10, dimStepSeconds ? 0.05, minBrightnessPercents ? 1}:
let
  light = "${pkgs.light}/bin/light";
  fish = "${pkgs.fish}/bin/fish";
  steps = builtins.toString (builtins.div dimSeconds dimStepSeconds);
  dimStepSeconds' = builtins.toString dimStepSeconds;
  minBrightnessPercents' = builtins.toString minBrightnessPercents;
in pkgs.writeTextFile {
  name = "dim-screen";
  executable = true;
  destination = "/bin/dim-screen";
  text = ''
    #!${fish}

    function exit_handler --on-process-exit %self
      ${light} -I # Restore state.
    end

    function signal_handler --on-signal SIGTERM --on-signal SIGINT
      exit
    end

    set brightness (light) # Get state.
    set step (math $brightness / ${steps})
    while test $brightness -gt ${minBrightnessPercents'}
      ${light} -S $brightness # Set state.
      set brightness (math $brightness - $step) # Compute next state.
      sleep ${dimStepSeconds'}
    end
  
    ${light} -S ${minBrightnessPercents'}
    sleep 1000000000 &
    wait
  '';
  checkPhase = ''
    ${fish} -n $out
  '';
}

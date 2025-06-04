{
  pkgs,
  fetchFromGitHub,
  openai
}:
pkgs.unstable.buildHomeAssistantComponent rec {
  owner = "jekalmin";
  domain = "extended_openai_conversation";
  version = "1.0.5-beta2";

  src = fetchFromGitHub {
    inherit owner;
    repo = domain;
    tag = "${version}";
    hash = "sha256-peg3YO1dgpKtmhvH2Kt9AsLXyg0OmJZof0RE03Kpe8E=";
  };

  dependencies = [
    openai
  ];

  ignoreVersionRequirement = [
    "openai"
  ];
}

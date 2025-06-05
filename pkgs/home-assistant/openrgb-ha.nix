{
  fetchFromGitHub,
  openrgb-python,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "openrgb-ha";
  domain = "openrgb";
  version = "2.7.0";

  src = fetchFromGitHub {
    inherit owner;
    repo = "openrgb-ha";
    tag = "v${version}";
    hash = "sha256-cTOkTyOU3aBXIGU1FL1boKU/6RIeFMC8yKc+0wcTVUU=";
  };

  dependencies = [
    openrgb-python
  ];

  ignoreVersionRequirement = [
    "openrgb-python"
  ];
}

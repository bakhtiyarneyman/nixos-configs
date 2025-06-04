{
  fetchFromGitHub,
  buildHomeAssistantComponent,
  pillow,
  pybase64,
  python-miio,
  requests,
  pycryptodome,
}:
buildHomeAssistantComponent rec {
  owner = "PiotrMachowski";
  domain = "xiaomi_cloud_map_extractor";
  version = "2.2.3";

  src = fetchFromGitHub {
    inherit owner;
    repo = "Home-Assistant-custom-components-Xiaomi-Cloud-Map-Extractor";
    tag = "v${version}";
    hash = "sha256-vC3RGavmL0bJFQ5cxPBHuKfKcw34wF4gcZrxA6yVaMY=";
  };

  dependencies = [
    pillow
    pybase64
    python-miio
    requests
    pycryptodome
  ];
}

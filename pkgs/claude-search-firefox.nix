{
  stdenv,
  lib,
  fetchFromGitHub,
  zip,
}:
stdenv.mkDerivation {
  pname = "claude-search-firefox";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "MadDogofShimano";
    repo = "claude-search-firefox";
    rev = "8b1fa5190dfd03a81b2fb55b6448265fece9a8fd";
    hash = "sha256-J2QHbfw8C+iQOKqqbOOrYwOMqthgzG6+zIFiUTDoj2k=";
  };

  nativeBuildInputs = [zip];

  buildPhase = ''
    runHook preBuild
    zip -rq claude-search@extension.xpi manifest.json content.js icons/
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 claude-search@extension.xpi -t $out
    runHook postInstall
  '';

  meta = with lib; {
    description = "Use @claude in Firefox address bar to prompt Claude directly";
    homepage = "https://github.com/MadDogofShimano/claude-search-firefox";
    license = licenses.gpl3Only;
    platforms = platforms.all;
  };
}

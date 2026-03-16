{
  buildNpmPackage,
  fetchurl,
  lib,
}:
buildNpmPackage rec {
  pname = "firecrawl-cli";
  version = "1.9.8";

  src = fetchurl {
    url = "https://registry.npmjs.org/firecrawl-cli/-/firecrawl-cli-${version}.tgz";
    hash = "sha512-N5wLTtt3GWO1bJFbo0VTJHLNFVkov7nbK1CgfeOaAgG/YO8qwIZADYg1xlFqzrbNRA9nRwJEdiX+HvdBjGDnkQ==";
  };
  sourceRoot = "package";
  npmDepsHash = "sha256-px6haHn13hv1ecdUCobIPhR/+p0c6GtuKWMFge5UCII=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [
    "--legacy-peer-deps"
  ];

  npmInstallFlags = [
    "--omit=dev"
    "--ignore-scripts"
  ];
  npmPackFlags = [
    "--ignore-scripts"
  ];

  dontNpmBuild = true;

  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/firecrawl" --version >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "CLI for Firecrawl web scraping and search workflows";
    homepage = "https://github.com/firecrawl/cli";
    license = licenses.isc;
    mainProgram = "firecrawl";
    platforms = platforms.unix;
  };
}

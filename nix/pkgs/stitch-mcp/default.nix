{
  buildNpmPackage,
  fetchurl,
  lib,
}:
buildNpmPackage rec {
  pname = "stitch-mcp";
  version = "0.5.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@_davideast/stitch-mcp/-/stitch-mcp-${version}.tgz";
    hash = "sha512-+uZnw9vQ7jlZ5EE6XGx8qGHfzKdDLMkDC2jDemk7usBkSJEYSQw+7ffxam6vz5bAHU19L2yhJAmd9456d3gJpA==";
  };
  sourceRoot = "package";
  npmDepsHash = "sha256-J4AVe+YNMGTEb4XyYosaIvJmx/jI3SGMpLNaGsD7KgQ=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmInstallFlags = [
    "--omit=dev"
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];
  npmPackFlags = [
    "--ignore-scripts"
  ];

  dontNpmBuild = true;
  dontNpmPrune = true;

  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" "$out/bin/stitch-mcp" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Stitch MCP CLI helper and proxy";
    homepage = "https://github.com/davideast/stitch-mcp";
    license = licenses.asl20;
    mainProgram = "stitch-mcp";
    platforms = platforms.unix;
  };
}

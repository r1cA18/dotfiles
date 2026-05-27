{
  buildNpmPackage,
  fetchurl,
  lib,
}:
buildNpmPackage rec {
  pname = "difit";
  version = "4.0.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/difit/-/difit-${version}.tgz";
    hash = "sha512-93EK3Am0QkLSPjFZGI+8bcvkbyozLCSRZuEh7t55nyQXyVTiyzI0SpOakR5nHutI7r631WECaQTDacfUe5jlCw==";
  };
  sourceRoot = "package";

  npmDepsHash = "sha256-HcuOBEJk4BuCxb5eeWXbvy+28frvUikd+uUmeCsWE4Y=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  npmFlags = [
    "--legacy-peer-deps"
  ];

  npmInstallFlags = [
    "--omit=dev"
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];
  npmPackFlags = [
    "--ignore-scripts"
  ];

  meta = with lib; {
    description = "Git diff viewer for AI-generated code review";
    homepage = "https://github.com/yoshiko-pg/difit";
    license = licenses.mit;
    mainProgram = "difit";
    platforms = platforms.unix;
  };
}

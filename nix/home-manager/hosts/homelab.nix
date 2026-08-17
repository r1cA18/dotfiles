{ config, ... }:
{
  imports = [ ../home.nix ];

  # MacBook (RMB). The new homelab gets its own Syncthing identity on first
  # start. Since this host already knows RMB, only RMB needs to accept the new
  # device once; the folder IDs remain stable across the migration.
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      options = {
        localAnnounceEnabled = true;
        relaysEnabled = true;
        urAccepted = -1;
      };
      devices.RMB = {
        id = "VI7PYJO-2DJSWXG-7XNU6XB-KKMELIW-UF2GYL5-DF5HYGN-HSUJ5KU-NZWBEAA";
        addresses = [ "dynamic" ];
      };
      folders = {
        vault = {
          id = "ecvg9-qifz9";
          label = "vault";
          path = "${config.home.homeDirectory}/vault";
          type = "sendreceive";
          devices = [ "RMB" ];
          ignorePerms = true;
          fsWatcherEnabled = true;
          rescanIntervalS = 3600;
          maxConflicts = 20;
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "2592000";
            };
          };
        };
        Develop = {
          id = "tj9sr-r4ieg";
          label = "Develop";
          path = "${config.home.homeDirectory}/Develop";
          type = "sendreceive";
          devices = [ "RMB" ];
          ignorePerms = true;
          fsWatcherEnabled = true;
          rescanIntervalS = 3600;
          maxConflicts = 20;
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "2592000";
            };
          };
        };
      };
    };
  };
}

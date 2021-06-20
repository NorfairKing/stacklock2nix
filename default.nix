{ stackYaml 
, stackYamlLock ? stackYaml + ".lock"
, pkgs ? import <nixpkgs> {}
}:

with pkgs.lib;
let
  mergeListRecursively = pkgs.callPackage ./merge-lists-recursively.nix { };

  traceId = x: builtins.trace x x;

  fromYamlFile = yamlFile: builtins.fromJSON (builtins.readFile (
    pkgs.stdenv.mkDerivation {
      name = "stack.yaml.lock.json";
      buildInputs = [ pkgs.yaml2json ];
      src = yamlFile;
      buildCommand = ''
        cat $src | yaml2json > $out
      '';
  }));
  stackYamlLockContents = fromYamlFile stackYamlLock;
  snapshotFile = 
    let snapshot = (builtins.head stackYamlLockContents.snapshots);
    in builtins.fetchurl { inherit (snapshot.completed) url sha256; };
  snapshotFileContents = fromYamlFile snapshotFile;
  turnPackageDescriptionIntoPackage = packageYamlContents:
    if builtins.hasAttr "hackage" packageYamlContents
    then 
    let nameVersionAndHash = packageYamlContents.hackage;
        pieces = splitString "@" nameVersionAndHash;
        nameAndVersion = head pieces;
        hashAndSize = last pieces;
        namePieces = splitString "-" nameAndVersion;
        name = concatStringsSep "-" (init namePieces);
        version = last namePieces;
      in { "${name}" = pkgs.haskellPackages.callHackage name version {}; }
    else builtins.trace "Not implemented yet." null;
    
  result = builtins.map turnPackageDescriptionIntoPackage snapshotFileContents.packages;
    
in builtins.head result

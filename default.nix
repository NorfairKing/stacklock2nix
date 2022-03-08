{
  stackYaml,
  all-cabal-hashes ? pkgs.all-cabal-hashes,
  stackYamlLock ? stackYaml + ".lock",
  sources ? import ./nix/sources.nix,
  src ? null,
  pkgs ? import sources.nixpkgs { },
} @ args:

let
  lib = pkgs.lib;
  l = builtins // lib;

  traceId = x: builtins.trace x x;
  fromYamlFile = pkgs.callPackage ./lib/fromYamlFile.nix { };

  # Contents of the stack.yaml.lock file in nix format
  stackYamlLockContents = fromYamlFile stackYamlLock;

  # The stack.yaml.lock file contains a section of this form:
  #
  # snapshots:
  # - completed:
  #     size: 532377
  #     url: https://raw.githubusercontent.com/commercialhaskell/stackage-snapshots/master/lts/16/12.yaml
  #     sha256: f914cfa23fef85bdf895e300a8234d9d0edc2dbec67f4bc9c53f85867c50eab6
  #   original: lts-16.12
  #
  # We fetch that url using that sha256 here:
  snapshotFile =
    let snapshot = (builtins.head stackYamlLockContents.snapshots);
    in builtins.fetchurl { inherit (snapshot.completed) url sha256; };

  # Then we read it into nix format
  snapshotFileContents = fromYamlFile snapshotFile;

  getPackageInfo = packageYamlContents:
    if ! builtins.hasAttr "hackage" packageYamlContents
    then l.throw "Not implemented yet."
    else
      let
        # AC-Angle-1.0@sha256:e1ffee97819283b714598b947de323254e368f6ae7d4db1d3618fa933f80f065,544
        nameVersionAndHash = packageYamlContents.hackage;
        # [ "AC-Angle-1.0" "sha256:e1ffee97819283b714598b947de323254e368f6ae7d4db1d3618fa933f80f065,544" ]
        pieces = lib.splitString "@" nameVersionAndHash;
        # "AC-Angle-1.0"
        nameAndVersion = lib.head pieces;
        # "sha256:e1ffee97819283b714598b947de323254e368f6ae7d4db1d3618fa933f80f065,544"
        hashAndSize = lib.last pieces;
        # [ "AC" "Angle" "1.0" ]
        namePieces = lib.splitString "-" nameAndVersion;
        # "AC-Angle"
        name = lib.concatStringsSep "-" (lib.init namePieces);
        # "1.0"
        version = lib.last namePieces;
        # [ "sha256:e1ffee97819283b714598b947de323254e368f6ae7d4db1d3618fa933f80f065" "544" ]
        hashPieces = lib.splitString "," hashAndSize;
        # "sha256:e1ffee97819283b714598b947de323254e368f6ae7d4db1d3618fa933f80f065"
        hash = lib.head hashPieces;
        # "544'
        size = lib.last hashPieces;
      in {
        inherit name;
        version = l.trace name version;
      };

  # The snapshot file that we downloaded contains a section like this:
  #
  # packages:
  # - hackage: AC-Angle-1.0@sha256:e1ffee97819283b714598b947de323254e368f6ae7d4db1d3618fa933f80f065,544
  #   pantry-tree:
  #     size: 210
  #     sha256: 7edd1f1a6228af27c0f0ae53e73468c1d7ac26166f2cb386962db7ff021a2714
  #
  # The following function turns an element in this list into something of the following format, based on what we find in
  # the `pkgs/development/haskell-modules/hackage-packages.nix` file in nixpkgs:
  #
  # "AC-Angle" = callPackage
  #   ({ mkDerivation, base }:
  #    mkDerivation {
  #      pname = "AC-Angle";
  #      version = "1.0";
  #      sha256 = "0ra97a4im3w2cq3mf17j8skn6bajs7rw7d0mmvcwgb9jd04b0idm";
  #      libraryHaskellDepends = [ base ];
  #      description = "Angles in degrees and radians";
  #      license = lib.licenses.bsd3;
  #    }) {};
  turnPackageDescriptionIntoPackage =
    self:
    { pkgs, lib, callPackage }:
    packageInfo:
    let

      package = self.hackage2nix packageInfo.name packageInfo.version;

      pkg = ((x: builtins.trace "${x}" x) package);
    in
      pkgs.haskell.lib.overrideCabal
        (callPackage
          pkg
          (lib.optionalAttrs (packageInfo.name == "splitmix") {
            testu01 = null;
          }))
        {
          # Turn off all tests so that we definitely don't get any infinite recursion
          # when one library's tests depend on a library that depends on that library.
          # In this way:
          # A's test -> B's lib -> A's lib
          doCheck = false;
          doBenchmark = false;
          doHaddock = false;
          doHoogle = false;
          enableExecutableProfiling = false;
          hyperlinkSource = false;
        };

  # This set is just that entire file
  snapshotPackageSetFunction = args@{ pkgs, lib, callPackage }: self:
    let
      packageInfosByName = l.listToAttrs
        (l.forEach snapshotFileContents.packages
          (yaml: let
            parsed = getPackageInfo yaml;
          in
            l.nameValuePair
              parsed.name
              parsed));
    in
      l.mapAttrs
        (name: info: turnPackageDescriptionIntoPackage self args info)
        packageInfosByName;

  # The contents of the stack.yaml file in nix format
  stackYamlContents = fromYamlFile stackYaml;

  hiddenPackagesSet =
    builtins.mapAttrs (_: value: null) snapshotFileContents.hidden // {
      array = null;
      base = null;
      binary = null;
      bytestring = null;
      Cabal = null;
      containers = null;
      deepseq = null;
      directory = null;
      filepath = null;
      ghc-boot = null;
      ghc-boot-th = null;
      ghc-compact = null;
      ghc-heap = null;
      ghc-prim = null;
      ghci = null;
      haskeline = null;
      hpc = null;
      integer-gmp = null;
      libiserv = null;
      mtl = null;
      parsec = null;
      pretty = null;
      process = null;
      rts = null;
      stm = null;
      template-haskell = null;
      terminfo = null;
      text = null;
      time = null;
      transformers = null;
      unix = null;
      xhtml = null;
    };


  localPackagePath = builtins.head stackYamlContents.packages;

  localPkgDerivationFunc = self: { pkgs, lib, callPackage }:
    callPackage
      (self.haskellSrc2nix {
        name = "local-test";
        src = args.src or (builtins.dirOf (stackYaml + "/${localPackagePath}"));
      })
      { };

  totalPackageSetFunction = args@{ pkgs, lib, callPackage }: self:
    hiddenPackagesSet //
    snapshotPackageSetFunction args self //
    ({ "local-test" = localPkgDerivationFunc self args; });


  haskellPackagesFunc = pkgs.haskell.lib.makePackageSet {
    inherit all-cabal-hashes;
    buildPackages = pkgs;
    buildHaskellPackages = pkgs.haskellPackages;
    pkgs = pkgs;
    stdenv = pkgs.stdenv;
    lib = pkgs.lib;
    haskellLib = pkgs.haskell.lib;
    ghc = pkgs.haskell.compiler.ghc884;
    package-set = totalPackageSetFunction;
    extensible-self = haskellPackages;
  };
  haskellPackages = lib.makeExtensible haskellPackagesFunc;


in
haskellPackages

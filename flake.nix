{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";

    all-cabal-hashes.url = "github:commercialhaskell/all-cabal-hashes/hackage";
    all-cabal-hashes.flake = false;

    shellcheck.url = "github:koalaman/shellcheck/88cdb4e2c9b45becb21bd02cd7b205d5bef8cb56";
    shellcheck.flake = false;
  };

  outputs = {
    all-cabal-hashes,
    nixpkgs,
    shellcheck,
    self,
  } @ inp: let

    l = nixpkgs.lib // builtins;
    supportedSystems = [ "x86_64-linux" ];

    forAllSystems = f: l.genAttrs supportedSystems
      (system: f system (nixpkgs.legacyPackages.${system}));

    stacklock2nixFor = forAllSystems
      (system: pkgs: args: import ./default.nix ({
        inherit pkgs;
        all-cabal-hashes = pkgs.runCommand "all-cabal-hashes.tar.gz" {} ''
          cp -r ${all-cabal-hashes} all-cabal-hashes
          tar -c all-cabal-hashes | ${pkgs.pigz}/bin/pigz -1 > $out
        '';
      } // args));

  in {

    checks = forAllSystems (system: pkgs: {
      shellcheck = (stacklock2nixFor.${system} {
        stackYaml = ./test/shellcheck.yaml;
        src = shellcheck;
      }).local-test;
    });
  };
}

{
  sources ? import ./nix/sources.nix,
  pkgs ? import sources.nixpkgs { },
  stackYaml ? ./local-test/stack.yaml,
}:
let
  stacklock2nix = args: import ./default.nix ({ inherit sources pkgs; } // args);

  testProjects = {
    local-test = { inherit stackYaml; };
  };

in
pkgs.lib.mapAttrs (_: args: stacklock2nix args) testProjects

let
  pkgs = import <nixpkgs> {};
  stacklock2nix = args: import ./default.nix ({ inherit pkgs; } // args) ;

  testProjects = {
    local-test = { stackYaml = ./local-test/stack.yaml; };
  };

in pkgs.lib.mapAttrs (_: args: stacklock2nix args) testProjects
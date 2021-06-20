let
  stacklock2nix = import ./default.nix;

in
  stacklock2nix {
    stackYaml = ./test/stack.yaml;
  }


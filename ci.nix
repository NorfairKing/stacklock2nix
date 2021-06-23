let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { inherit sources; };
  pre-commit-hooks = import ./nix/pre-commit.nix { inherit sources; };
  tests = import ./tests.nix { inherit sources pkgs; };
in
{
  pre-commit-check = pre-commit-hooks.run;
} // tests

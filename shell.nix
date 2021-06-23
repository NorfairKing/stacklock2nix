let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { inherit sources; };
  pre-commit = import ./nix/pre-commit.nix { inherit sources; };
in
pkgs.mkShell {
  name = "stacklock2nix-shell";
  buildInputs = with pkgs; [
    (import sources.niv { }).niv
  ] ++ pre-commit.tools;
  shellHook = pre-commit.run.shellHook;
}

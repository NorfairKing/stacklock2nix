{ stdenv, yaml2json }:

yamlFile:

builtins.fromJSON (builtins.readFile (
  stdenv.mkDerivation {
    name = "stack.yaml.lock.json";
    buildInputs = [ yaml2json ];
    src = yamlFile;
    buildCommand = ''
      cat $src | yaml2json > $out
    '';
}))

{ pkgs ? import <nixpkgs> {}
# { pkgs ? import (builtins.fetchTarball "https://github.com/nixos/nixpkgs-channels/archive/7305796f85caae3cc00b756388f72974f3530f3f.tar.gz") {}
, compiler ? "default"
, root ? ./.
, name ? "quickspec"
, source-overrides ? {}
, ...
}:
let
  haskellPackages =
    if compiler == "default"
      then pkgs.haskellPackages
      else pkgs.haskell.packages.${compiler};
in
haskellPackages.developPackage {
  root = root;
  name = name;
  source-overrides = {
    # clay = import ./nix/haskell/clay { };
    # pandoc-include-code = import ./nix/haskell/pandoc-include-code { };
    quickspec = ./.;
  } // source-overrides;

  overrides = self: super: with pkgs.haskell.lib; {
    # clay = dontCheck super.clay;
  };

  modifier = drv: pkgs.haskell.lib.overrideCabal drv (attrs: {
    buildTools = with haskellPackages; (attrs.buildTools or []) ++ [cabal-install ghcid] ;
  });
}


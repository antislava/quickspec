{ pkgs ? import <nixpkgs> {}
# { pkgs ? import (builtins.fetchTarball "https://github.com/nixos/nixpkgs-channels/archive/7305796f85caae3cc00b756388f72974f3530f3f.tar.gz") {}
, compiler ? "default"
, root ? ./.
, name ? "quickspec"
, source-overrides ? {}
, haskell-extra ? ps: [ ps.cabal-install ps.ghcid ]
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
    buildTools = (attrs.buildTools or []) ++ (haskell-extra haskellPackages) ;
    shellHook = ''
      echo "For development shell run"
      echo "$ nix-shell"
      echo "For test shell run"
      echo "$ nix-shell --arg haskell-extra 'ps: with ps; [ cabal-install ghcid quickspec ]'"
    '';
  });
}

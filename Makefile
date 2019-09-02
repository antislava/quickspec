dev-shell :
	nix-shell

test-shell :
	nix-shell --arg haskell-extra 'ps: with ps; [ cabal-install ghcid quickspec ]

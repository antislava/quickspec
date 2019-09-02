dev-shell :
	nix-shell

test-shell :
	nix-shell --arg haskell-extra 'ps: with ps; [ cabal-install ghcid quickspec ]'

clean:
	@echo "Removing ignored files and directories..."
	git clean -fdX
	@echo "To clean the rest do check in/stash important changes (just in case) and"
	@echo "$$ git clean -fd"

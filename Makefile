.PHONY: test clean

test: deps/plenary.nvim
	./scripts/test

deps/plenary.nvim:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $@

clean:
	rm -rf deps/plenary.nvim


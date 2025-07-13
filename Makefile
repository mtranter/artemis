

PKG_FILES := $(shell find ./src -name '*.pkg.json')
EXE := ./target/native/release/build/artemis.exe 

# Checks for pre-requisites like cc or gcc and pkg-config
.pre-check:
	@echo "Checking for required tools..."
	@command -v cc >/dev/null 2>&1 || { echo >&2 "I require cc but it's not installed.  Aborting."; exit 1; }
	@command -v pkg-config >/dev/null 2>&1 || { echo >&2 "I require pkg-config but it's not installed.  Aborting."; exit 1; }
	@touch .pre-check

.mooncakes: $(PKG_FILES)
	@echo "Running mooncakes to generate packages..."
	@moon install
install: .mooncakes

$(EXE): $(PKG_FILES) .pre-check .mooncakes
	@moon build --target native

build: $(EXE) .mooncakes

dev: $(EXE) .mooncakes
	@echo "Running Artemis in development mode..."
	@moon run ./src/server.mbt --target native
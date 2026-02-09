# Bee Task Manager - Build & Installation
# Installs both the CLI tool (bee) and macOS app (Bee.app)

.PHONY: install uninstall install-cli install-app build-cli build-app clean help

# Installation paths
CLI_INSTALL_DIR = $(HOME)/.local/bin
APP_INSTALL_DIR = /Applications

# Build directories
CARGO_TARGET_DIR = target/release
DERIVED_DATA_DIR = $(CURDIR)/build

# Default target
help:
	@echo "Bee Task Manager - Available targets:"
	@echo "  make install        Build and install both CLI (bee) and app (Bee.app)"
	@echo "  make install-cli    Build and install only the CLI tool to ~/.local/bin"
	@echo "  make install-app    Build and install only Bee.app to /Applications"
	@echo "  make uninstall      Remove both CLI and app"
	@echo "  make build-cli      Build only the CLI tool"
	@echo "  make build-app      Build only the macOS app"
	@echo "  make clean          Clean all build artifacts"

# Full installation: both CLI and app
install: install-cli install-app

# Build and install CLI to ~/.local/bin
install-cli: build-cli
	@echo "Installing bee CLI to $(CLI_INSTALL_DIR)..."
	@mkdir -p $(CLI_INSTALL_DIR)
	@cp -p $(CARGO_TARGET_DIR)/bee $(CLI_INSTALL_DIR)/bee
	@echo "✓ bee CLI installed to $(CLI_INSTALL_DIR)/bee"
	@echo ""
	@echo "Make sure $(CLI_INSTALL_DIR) is in your PATH"

# Build and install macOS app to /Applications
install-app: build-app
	@echo "Installing Bee.app to $(APP_INSTALL_DIR)..."
	@rm -rf $(APP_INSTALL_DIR)/Bee.app
	@cp -R "$(DERIVED_DATA_DIR)/Build/Products/Release/Bee.app" $(APP_INSTALL_DIR)/
	@echo "✓ Bee.app installed to $(APP_INSTALL_DIR)/Bee.app"
	@echo ""
	@echo "Launch from /Applications/Bee.app or via Spotlight"

# Remove both CLI and app
uninstall:
	@echo "Uninstalling bee..."
	@rm -f $(CLI_INSTALL_DIR)/bee
	@echo "✓ Removed $(CLI_INSTALL_DIR)/bee"
	@rm -rf $(APP_INSTALL_DIR)/Bee.app
	@echo "✓ Removed $(APP_INSTALL_DIR)/Bee.app"

# Build CLI in release mode
build-cli:
	@echo "Building bee CLI (release mode)..."
	@cargo build -p bee-cli --release
	@echo "✓ bee CLI built: $(CARGO_TARGET_DIR)/bee"

# Build macOS app (Xcode build script will automatically build and embed beed)
build-app:
	@echo "Building Bee.app with Xcode (Release)..."
	@cd macos-launcher/Bee && xcodebuild \
		-scheme Bee \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		build
	@echo "✓ Bee.app built: $(DERIVED_DATA_DIR)/Build/Products/Release/Bee.app"

# Clean all build artifacts
clean:
	@echo "Cleaning Cargo build artifacts..."
	@cargo clean
	@echo "Cleaning Xcode build artifacts..."
	@cd macos-launcher/Bee && xcodebuild \
		-scheme Bee \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA_DIR) \
		clean
	@rm -rf $(DERIVED_DATA_DIR)
	@echo "✓ All build artifacts cleaned"

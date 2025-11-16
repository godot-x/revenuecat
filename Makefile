.PHONY: help clean clean-godot setup-godot build-godot-headers setup-apple build-apple build-android build-all package setup-sdk unsign-sdk

# ============================================================================
# Directory Configuration (based on ROOT_DIR)
# ============================================================================
ROOT_DIR := $(shell pwd)

# Source directories
GODOT_DIR         = $(ROOT_DIR)/godot
SOURCE_DIR        = $(ROOT_DIR)/source
IOS_SOURCE_DIR    = $(SOURCE_DIR)/ios/revenue_cat
ANDROID_SOURCE_DIR= $(SOURCE_DIR)/android/revenue_cat
ADDONS_DIR        = $(ROOT_DIR)/addons/godotx_revenuecat

# Output directories
IOS_PLUGINS_DIR   = $(ROOT_DIR)/ios/plugins
ANDROID_OUTPUT_DIR= $(ROOT_DIR)/android

# Binary directories
REVENUECAT_SDK_DIR = $(ROOT_DIR)/source/ios/revenue_cat_sdk
REVENUECAT_UI_SDK_DIR = $(ROOT_DIR)/source/ios/revenue_cat_ui_sdk

# Temporary directories
TMP_DIR = /tmp

# ============================================================================
# Module Configuration
# ============================================================================
APPLE_MODULE      = revenue_cat
APPLE_MODULE_NAME = RevenueCat

ANDROID_MODULE    = revenue_cat

# ============================================================================
# Build Configuration
# ============================================================================
BUILD_CONFIGS    = Debug Release
APPLE_SDK_ARCHS  = iphoneos/arm64 iphonesimulator/arm64 iphonesimulator/x86_64

# ============================================================================
# Version Configuration
# ============================================================================
GODOT_VERSION = 4.5-stable
GODOT_REPO    = https://github.com/godotengine/godot.git
REVENUECAT_VERSION = 5.48.0

# ============================================================================
# Help
# ============================================================================

help:
	@echo "Godotx RevenueCat Build System"
	@echo "================================"
	@echo ""
	@echo "Available targets:"
	@echo "  setup-godot         - Clone/update Godot source (required for compilation)"
	@echo "  build-godot-headers - Generate Godot headers (required for iOS plugin compilation)"
	@echo "  setup-sdk           - Download RevenueCat SDK"
	@echo "  unsign-sdk          - Remove signatures from RevenueCat SDK frameworks"
	@echo "  setup-apple         - Install Apple dependencies (CocoaPods + XcodeGen) for RevenueCat"
	@echo "  build-apple         - Build iOS RevenueCat plugin (GodotxRevenueCat xcframework + .gdip)"
	@echo "  build-android       - Build Android RevenueCat plugin (.aar)"
	@echo "  build-all           - Build everything (Apple + Android)"
	@echo "  package             - Create distribution package (godotx_revenuecat.zip)"
	@echo "  clean               - Clean build artifacts"
	@echo "  clean-godot         - Remove Godot source"

# ============================================================================
# Godot Setup Targets
# ============================================================================

setup-godot:
	@echo "====================================================================="
	@echo "Setting up Godot source code..."
	@echo "====================================================================="
	@echo ""
	@if [ -d "$(GODOT_DIR)" ]; then \
		echo "→ Godot directory already exists"; \
		cd $(GODOT_DIR) && \
		echo "  • Fetching latest changes..." && \
		git fetch origin && \
		echo "  • Checking out $(GODOT_VERSION)..." && \
		git checkout $(GODOT_VERSION) && \
		git pull origin $(GODOT_VERSION) && \
		cd ..; \
		echo "  ✓ Godot updated to $(GODOT_VERSION)"; \
	else \
		echo "→ Cloning Godot repository..."; \
		git clone --depth 1 --branch $(GODOT_VERSION) $(GODOT_REPO) $(GODOT_DIR) && \
		echo "  ✓ Godot $(GODOT_VERSION) cloned successfully"; \
	fi
	@echo ""
	@echo "====================================================================="
	@echo "✓ Godot source ready!"
	@echo "====================================================================="

build-godot-headers: setup-godot
	@echo "====================================================================="
	@echo "Building Godot headers..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Generating iOS headers with scons..."
	@cd $(GODOT_DIR) && scons platform=ios target=template_release
	@echo ""
	@echo "====================================================================="
	@echo "✓ Godot headers generated!"
	@echo "====================================================================="

setup-sdk:
	@echo "====================================================================="
	@echo "Setting up RevenueCat SDK..."
	@echo "====================================================================="
	@echo ""
	@if [ ! -d "$(REVENUECAT_SDK_DIR)" ]; then \
		echo "→ Downloading RevenueCat SDK..."; \
		rm -rf $(TMP_DIR)/RevenueCat.zip $(TMP_DIR)/revenuecat_temp; \
		curl -L -o $(TMP_DIR)/RevenueCat.zip https://github.com/RevenueCat/purchases-ios/releases/download/$(REVENUECAT_VERSION)/RevenueCat.xcframework.zip; \
		echo "→ Extracting RevenueCat SDK..."; \
		unzip -q $(TMP_DIR)/RevenueCat.zip -d $(TMP_DIR)/revenuecat_temp; \
		echo "→ Moving to ios/revenue_cat..."; \
		mkdir -p $(REVENUECAT_SDK_DIR); \
		mv $(TMP_DIR)/revenuecat_temp/RevenueCat/* $(REVENUECAT_SDK_DIR)/; \
		touch $(REVENUECAT_SDK_DIR)/.gdignore; \
		rm -rf $(TMP_DIR)/RevenueCat.zip $(TMP_DIR)/revenuecat_temp; \
		echo "  ✓ RevenueCat SDK installed"; \
	else \
		echo "  ✓ RevenueCat SDK already present"; \
	fi

	@if [ ! -d "$(REVENUECAT_UI_SDK_DIR)" ]; then \
		echo ""; \
		echo "→ Downloading RevenueCatUI..."; \
		rm -rf $(TMP_DIR)/RevenueCatUI.zip $(TMP_DIR)/revenuecatui_temp; \
		curl -L -o $(TMP_DIR)/RevenueCatUI.zip https://github.com/RevenueCat/purchases-ios/releases/download/$(REVENUECAT_VERSION)/RevenueCatUI.xcframework.zip; \
		echo "→ Extracting RevenueCatUI..."; \
		unzip -q $(TMP_DIR)/RevenueCatUI.zip -d $(TMP_DIR)/revenuecatui_temp; \
		echo "→ Moving to ios/revenue_cat_ui..."; \
		mkdir -p $(REVENUECAT_UI_SDK_DIR); \
		mv $(TMP_DIR)/revenuecatui_temp/RevenueCatUI/* $(REVENUECAT_UI_SDK_DIR)/; \
		touch $(REVENUECAT_UI_SDK_DIR)/.gdignore; \
		rm -rf $(TMP_DIR)/RevenueCatUI.zip $(TMP_DIR)/revenuecatui_temp; \
		echo "  ✓ RevenueCatUI installed"; \
	else \
		echo "  ✓ RevenueCatUI already present"; \
	fi

	@echo ""
	@echo "====================================================================="
	@echo "✓ RevenueCat SDK + UI ready!"
	@echo "====================================================================="

unsign-sdk:
	@echo "====================================================================="
	@echo "Removing signatures from RevenueCat SDK frameworks..."
	@echo "====================================================================="
	@echo ""
	# remove pastas de assinatura dos bundles
	@find $(REVENUECAT_SDK_DIR) -name "_CodeSignature" -type d -exec rm -rf {} +
	@find $(REVENUECAT_UI_SDK_DIR) -name "_CodeSignature" -type d -exec rm -rf {} +
	@echo "  ✓ All _CodeSignature folders removed"
	@echo ""
	@echo "====================================================================="
	@echo "✓ RevenueCat frameworks are now UNSIGNED (build-safe)"
	@echo "====================================================================="

# ============================================================================
# Apple (iOS) RevenueCat Targets
# ============================================================================

setup-apple: setup-godot
	@echo "====================================================================="
	@echo "Setting up Apple (iOS) dependencies for RevenueCat..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Setting up $(APPLE_MODULE) (Godotx$(APPLE_MODULE_NAME))..."
	@(cd $(IOS_SOURCE_DIR) && \
		echo "  • Creating build directory..." && \
		rm -rf build && mkdir -p build && \
		touch build/.gdignore && \
		echo "  • Generating Xcode project via XcodeGen..." && \
		xcodegen generate -s project.yml -p build/ && \
		echo "  • Installing CocoaPods..." && \
		cp Podfile build/ && \
		pod install --repo-update --project-directory=build)
	@echo ""
	@echo "====================================================================="
	@echo "✓ Apple RevenueCat module setup complete!"
	@echo "====================================================================="

build-apple: setup-apple
	@echo "====================================================================="
	@echo "Building Apple (iOS) RevenueCat module..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Building $(APPLE_MODULE) (Godotx$(APPLE_MODULE_NAME))..."
	@(cd $(IOS_SOURCE_DIR) && \
		rm -rf $(IOS_PLUGINS_DIR)/$(APPLE_MODULE) && \
		mkdir -p $(IOS_PLUGINS_DIR)/$(APPLE_MODULE) && \
		for config in $(BUILD_CONFIGS); do \
			config_lower=$$(echo $$config | tr '[:upper:]' '[:lower:]'); \
			echo "  • Building $$config configuration..."; \
			echo "    - Cleaning $$config..." && \
			xcodebuild clean -workspace build/Godotx$(APPLE_MODULE_NAME).xcworkspace \
				-scheme Godotx$(APPLE_MODULE_NAME) \
				-configuration $$config && \
			for sdk_arch in $(APPLE_SDK_ARCHS); do \
				sdk=$$(echo $$sdk_arch | cut -d/ -f1); \
				arch=$$(echo $$sdk_arch | cut -d/ -f2); \
				echo "    - Building $$config for $$sdk ($$arch)..." && \
				xcodebuild \
					-workspace build/Godotx$(APPLE_MODULE_NAME).xcworkspace \
					-scheme Godotx$(APPLE_MODULE_NAME) \
					-sdk $$sdk \
					-arch $$arch \
					-configuration $$config \
					SKIP_INSTALL=NO \
					BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
					CODE_SIGNING_ALLOWED=NO \
					CODE_SIGNING_REQUIRED=NO || exit 1; \
			done && \
			echo "    - Creating universal simulator library..." && \
			mkdir -p build/bin/$$config_lower-simulator && \
			lipo -create \
				build/bin/$$config_lower-iphonesimulator-arm64/libGodotx$(APPLE_MODULE_NAME).a \
				build/bin/$$config_lower-iphonesimulator-x86_64/libGodotx$(APPLE_MODULE_NAME).a \
				-output build/bin/$$config_lower-simulator/libGodotx$(APPLE_MODULE_NAME).a && \
			cp -r build/bin/$$config_lower-iphonesimulator-arm64/include build/bin/$$config_lower-simulator && \
			echo "    - Creating $$config XCFramework..." && \
			xcodebuild -create-xcframework \
				-library build/bin/$$config_lower-iphoneos-arm64/libGodotx$(APPLE_MODULE_NAME).a \
				-headers build/bin/$$config_lower-iphoneos-arm64/include \
				-library build/bin/$$config_lower-simulator/libGodotx$(APPLE_MODULE_NAME).a \
				-headers build/bin/$$config_lower-simulator/include \
				-output $(IOS_PLUGINS_DIR)/$(APPLE_MODULE)/Godotx$(APPLE_MODULE_NAME).$$config_lower.xcframework && \
			echo "    ✓ $$config build complete"; \
		done && \
		echo "    - Cleaning temporary build artifacts..." && \
		rm -rf bin && \
		rm -rf build && \
		echo "  • Copying .gdip file to output..." && \
		cp revenue_cat.gdip $(IOS_PLUGINS_DIR)/$(APPLE_MODULE)/ && \
		echo "  • Copying RevenueCat SDK frameworks..." && \
		cp -a $(REVENUECAT_SDK_DIR)/*.xcframework $(IOS_PLUGINS_DIR)/$(APPLE_MODULE)/ && \
		cp -a $(REVENUECAT_UI_SDK_DIR)/*.xcframework $(IOS_PLUGINS_DIR)/$(APPLE_MODULE)/ && \
		echo "  ✓ RevenueCat module build complete (Debug + Release)" \
	)
	@echo ""
	@echo "====================================================================="
	@echo "✓ Apple RevenueCat module built successfully!"
	@echo "====================================================================="


# ============================================================================
# Android RevenueCat Targets
# ============================================================================

build-android:
	@echo "====================================================================="
	@echo "Building Android RevenueCat module..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Building $(ANDROID_MODULE)..."
	@(cd $(ANDROID_SOURCE_DIR) && \
		echo "  • Running Gradle assembleDebug..." && \
		./gradlew assembleDebug && \
		echo "  • Running Gradle assembleRelease..." && \
		./gradlew assembleRelease)
	@echo "  • Creating output directory..."
	@rm -rf $(ANDROID_OUTPUT_DIR)/$(ANDROID_MODULE)
	@mkdir -p $(ANDROID_OUTPUT_DIR)/$(ANDROID_MODULE)
	@echo "  • Copying Debug AAR..."
	@cp $(ANDROID_SOURCE_DIR)/build/outputs/aar/*-debug.aar $(ANDROID_OUTPUT_DIR)/$(ANDROID_MODULE)/$(ANDROID_MODULE).debug.aar   2>/dev/null || true
	@echo "  • Copying Release AAR..."
	@cp $(ANDROID_SOURCE_DIR)/build/outputs/aar/*-release.aar $(ANDROID_OUTPUT_DIR)/$(ANDROID_MODULE)/$(ANDROID_MODULE).release.aar 2>/dev/null || true
	@touch $(ANDROID_OUTPUT_DIR)/$(ANDROID_MODULE)/.gdignore
	@echo ""
	@echo "====================================================================="
	@echo "✓ Android RevenueCat module built successfully!"
	@echo "====================================================================="
	@echo ""
	@echo "Generated AARs:"
	@ls -lh $(ANDROID_OUTPUT_DIR)/$(ANDROID_MODULE)/*.aar 2>/dev/null || echo "  (No AARs found)"

# ============================================================================
# Combined Targets
# ============================================================================

build-all: build-apple build-android
	@echo ""
	@echo "====================================================================="
	@echo "✓✓✓ ALL REVENUECAT MODULES BUILT SUCCESSFULLY! ✓✓✓"
	@echo "====================================================================="

package:
	@echo "====================================================================="
	@echo "Creating package..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Creating package directory..."
	@rm -rf godotx_revenue_cat
	@mkdir -p godotx_revenue_cat
	@echo "→ Copying addons..."
	@cp -a addons godotx_revenue_cat/
	@echo "→ Copying iOS plugin..."
	@cp -a ios/plugins/revenue_cat godotx_revenue_cat/ios/
	@echo "→ Copying Android plugin..."
	@mkdir -p godotx_revenue_cat/android
	@cp -a android/revenue_cat godotx_revenue_cat/android/
	@echo "→ Creating zip archive..."
	@zip -ry godotx_revenue_cat.zip godotx_revenue_cat
	@rm -rf godotx_revenue_cat
	@echo ""
	@echo "====================================================================="
	@echo "✓ Package created: godotx_revenue_cat.zip"
	@echo "====================================================================="

# ============================================================================
# Clean Targets
# ============================================================================

clean:
	@echo "====================================================================="
	@echo "Cleaning build artifacts..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Cleaning iOS RevenueCat..."
	@rm -rf $(IOS_PLUGINS_DIR)/$(APPLE_MODULE)
	@rm -rf $(IOS_SOURCE_DIR)/build
	@echo "→ Cleaning Android RevenueCat..."
	@rm -rf $(ANDROID_OUTPUT_DIR)/$(ANDROID_MODULE)
	@if [ -d "$(ANDROID_SOURCE_DIR)" ]; then \
		(cd $(ANDROID_SOURCE_DIR) && ./gradlew clean); \
	fi
	@echo ""
	@echo "====================================================================="
	@echo "✓ Clean complete!"
	@echo "====================================================================="

clean-godot:
	@echo "====================================================================="
	@echo "Removing Godot source..."
	@echo "====================================================================="
	@echo ""
	@if [ -d "$(GODOT_DIR)" ]; then \
		echo "→ Removing Godot directory..."; \
		rm -rf $(GODOT_DIR); \
		echo "  ✓ Godot source removed"; \
	else \
		echo "  • Godot directory does not exist"; \
	fi
	@echo ""
	@echo "====================================================================="
	@echo "✓ Done!"
	@echo "====================================================================="

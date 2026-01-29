.PHONY: help clean clean-godot \
setup-godot build-godot setup-apple \
build-apple build-android build-all \
package \
setup-sdk unsign-sdk

# ============================================================================
# Plugin Configuration
# ============================================================================
PLUGIN_NAME       = godotx_revenue_cat

APPLE_PLUGIN      = revenue_cat
APPLE_PLUGIN_NAME = RevenueCat

ANDROID_PLUGIN    = revenue_cat

# ============================================================================
# Directory Configuration (based on ROOT_DIR)
# ============================================================================
ROOT_DIR := $(shell pwd)

# Source directories
GODOT_CPP_DIR      = $(ROOT_DIR)/godot-cpp
SOURCE_DIR         = $(ROOT_DIR)/source
IOS_SOURCE_DIR     = $(SOURCE_DIR)/ios/revenue_cat
ANDROID_SOURCE_DIR = $(SOURCE_DIR)/android/revenue_cat
ADDONS_SOURCE_DIR  = $(SOURCE_DIR)/addons
BUILD_ROOT_DIR     = $(ROOT_DIR)/build
PACKAGE_DIR        = $(ROOT_DIR)/package
DEMO_DIR           = $(ROOT_DIR)/demo

# Output directories
IOS_OUTPUT_DIR     = $(BUILD_ROOT_DIR)/ios
ANDROID_OUTPUT_DIR = $(BUILD_ROOT_DIR)/android

# Binary directories
REVENUECAT_SDK_DIR    = $(ROOT_DIR)/source/ios/revenue_cat_sdk
REVENUECAT_UI_SDK_DIR = $(ROOT_DIR)/source/ios/revenue_cat_ui_sdk

# Temporary directories
TMP_DIR = /tmp

# ============================================================================
# Build Configuration
# ============================================================================
BUILD_CONFIGS    = Debug Release
APPLE_SDK_ARCHS  = iphoneos/arm64 iphonesimulator/arm64 iphonesimulator/x86_64

# ============================================================================
# Version Configuration
# ============================================================================
GODOT_CPP_VERSION = godot-4.5-stable
GODOT_CPP_REPO    = https://github.com/godotengine/godot-cpp.git

REVENUECAT_VERSION = 5.56.0

# ============================================================================
# Help
# ============================================================================

help:
	@echo "Godotx RevenueCat Build System"
	@echo "================================"
	@echo ""
	@echo "Available targets:"
	@echo "  setup-godot      - Clone/update Godot source (required for compilation)"
	@echo "  build-godot      - Generate Godot headers (required for iOS plugin compilation)"
	@echo "  setup-sdk        - Download RevenueCat SDK"
	@echo "  unsign-sdk       - Remove signatures from RevenueCat SDK frameworks"
	@echo "  setup-apple      - Install Apple dependencies (CocoaPods + XcodeGen) for RevenueCat"
	@echo "  build-apple      - Build iOS RevenueCat plugin (GodotxRevenueCat xcframework + .gdip)"
	@echo "  build-android    - Build Android RevenueCat plugin (.aar)"
	@echo "  build-all        - Build everything (Apple + Android)"
	@echo "  package          - Create distribution package (godotx_revenuecat.zip)"
	@echo "  demo-setup       - Setup demo project"
	@echo "  clean            - Clean build artifacts"
	@echo "  clean-godot      - Remove Godot source"

# ============================================================================
# Godot Setup Targets
# ============================================================================

setup-godot:
	@echo "====================================================================="
	@echo "Setting up godot-cpp..."
	@echo "====================================================================="
	@echo ""
	@if [ -d "$(GODOT_CPP_DIR)" ]; then \
		echo "→ Godot CPP source already exists"; \
		cd $(GODOT_CPP_DIR) && \
		echo "  • Fetching latest changes..." && \
		git fetch origin && \
		echo "  • Checking out $(GODOT_CPP_VERSION)..." && \
		git checkout $(GODOT_CPP_VERSION) && \
		git pull origin $(GODOT_CPP_VERSION); \
	else \
		echo "→ Cloning Godot CPP source repository..."; \
		git clone --depth 1 --branch $(GODOT_CPP_VERSION) $(GODOT_CPP_REPO) $(GODOT_CPP_DIR); \
	fi
	@echo ""
	@echo "====================================================================="
	@echo "✓ Godot CPP source ready"
	@echo "====================================================================="

build-godot: setup-godot
	@echo "====================================================================="
	@echo "Building Godot headers..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Generating iOS headers with scons..."
	@cd $(GODOT_CPP_DIR) && scons platform=ios target=template_release
	@echo ""
	@echo "====================================================================="
	@echo "✓ Godot headers generated!"
	@echo "====================================================================="

setup-sdk:
	@echo "====================================================================="
	@echo "Setting up External SDKs..."
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
	@echo "✓ External SDKs ready!"
	@echo "====================================================================="

unsign-sdk:
	@echo "====================================================================="
	@echo "Removing signatures from frameworks..."
	@echo "====================================================================="
	@echo ""
	# remove pastas de assinatura dos bundles
	@find $(REVENUECAT_SDK_DIR) -name "_CodeSignature" -type d -exec rm -rf {} +
	@find $(REVENUECAT_UI_SDK_DIR) -name "_CodeSignature" -type d -exec rm -rf {} +
	@echo "  ✓ All _CodeSignature folders removed"
	@echo ""
	@echo "====================================================================="
	@echo "✓ Frameworks are now UNSIGNED (build-safe)"
	@echo "====================================================================="

# ============================================================================
# Apple Targets
# ============================================================================

setup-apple: setup-godot
	@echo "====================================================================="
	@echo "Setting up Apple dependencies..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Setting up $(APPLE_PLUGIN) (Godotx$(APPLE_PLUGIN_NAME))..."
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
	@echo "✓ Apple setup complete!"
	@echo "====================================================================="

build-apple: setup-apple
	@echo "====================================================================="
	@echo "Building Apple (iOS) plugin..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Building $(APPLE_PLUGIN) (Godotx$(APPLE_PLUGIN_NAME))..."
	@(cd $(IOS_SOURCE_DIR) && \
		rm -rf $(IOS_OUTPUT_DIR)/$(APPLE_PLUGIN) && \
		mkdir -p $(IOS_OUTPUT_DIR)/$(APPLE_PLUGIN) && \
		for config in $(BUILD_CONFIGS); do \
			config_lower=$$(echo $$config | tr '[:upper:]' '[:lower:]'); \
			echo "  • Building $$config configuration..."; \
			echo "    - Cleaning $$config..." && \
			xcodebuild clean -workspace build/Godotx$(APPLE_PLUGIN_NAME).xcworkspace \
				-scheme Godotx$(APPLE_PLUGIN_NAME) \
				-configuration $$config && \
			for sdk_arch in $(APPLE_SDK_ARCHS); do \
				sdk=$$(echo $$sdk_arch | cut -d/ -f1); \
				arch=$$(echo $$sdk_arch | cut -d/ -f2); \
				echo "    - Building $$config for $$sdk ($$arch)..." && \
				xcodebuild \
					-workspace build/Godotx$(APPLE_PLUGIN_NAME).xcworkspace \
					-scheme Godotx$(APPLE_PLUGIN_NAME) \
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
				build/bin/$$config_lower-iphonesimulator-arm64/libGodotx$(APPLE_PLUGIN_NAME).a \
				build/bin/$$config_lower-iphonesimulator-x86_64/libGodotx$(APPLE_PLUGIN_NAME).a \
				-output build/bin/$$config_lower-simulator/libGodotx$(APPLE_PLUGIN_NAME).a && \
			cp -r build/bin/$$config_lower-iphonesimulator-arm64/include build/bin/$$config_lower-simulator && \
			echo "    - Creating $$config XCFramework..." && \
			xcodebuild -create-xcframework \
				-library build/bin/$$config_lower-iphoneos-arm64/libGodotx$(APPLE_PLUGIN_NAME).a \
				-headers build/bin/$$config_lower-iphoneos-arm64/include \
				-library build/bin/$$config_lower-simulator/libGodotx$(APPLE_PLUGIN_NAME).a \
				-headers build/bin/$$config_lower-simulator/include \
				-output $(IOS_OUTPUT_DIR)/$(APPLE_PLUGIN)/Godotx$(APPLE_PLUGIN_NAME).$$config_lower.xcframework && \
			echo "    ✓ $$config build complete"; \
		done && \
		echo "    - Cleaning temporary build artifacts..." && \
		rm -rf bin && \
		rm -rf build && \
		echo "  • Copying RevenueCat SDK frameworks..." && \
		cp -a $(REVENUECAT_SDK_DIR)/*.xcframework $(IOS_OUTPUT_DIR)/$(APPLE_PLUGIN)/ && \
		cp -a $(REVENUECAT_UI_SDK_DIR)/*.xcframework $(IOS_OUTPUT_DIR)/$(APPLE_PLUGIN)/ && \
		echo "  ✓ RevenueCat plugin build complete (Debug + Release)" \
	)
	@echo ""
	@echo "====================================================================="
	@echo "✓ Apple plugin built successfully!"
	@echo "====================================================================="


# ============================================================================
# Android Targets
# ============================================================================

build-android:
	@echo "====================================================================="
	@echo "Building android plugin..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Building $(ANDROID_PLUGIN)..."
	@(cd $(ANDROID_SOURCE_DIR) && \
		echo "  • Running Gradle assembleDebug..." && \
		./gradlew assembleDebug && \
		echo "  • Running Gradle assembleRelease..." && \
		./gradlew assembleRelease)
	@echo "  • Creating output directory..."
	@rm -rf $(ANDROID_OUTPUT_DIR)/$(ANDROID_PLUGIN)
	@mkdir -p $(ANDROID_OUTPUT_DIR)/$(ANDROID_PLUGIN)
	@echo "  • Copying Debug AAR..."
	@cp $(ANDROID_SOURCE_DIR)/build/outputs/aar/*-debug.aar $(ANDROID_OUTPUT_DIR)/$(ANDROID_PLUGIN)/$(ANDROID_PLUGIN).debug.aar   2>/dev/null || true
	@echo "  • Copying Release AAR..."
	@cp $(ANDROID_SOURCE_DIR)/build/outputs/aar/*-release.aar $(ANDROID_OUTPUT_DIR)/$(ANDROID_PLUGIN)/$(ANDROID_PLUGIN).release.aar 2>/dev/null || true
	@touch $(ANDROID_OUTPUT_DIR)/$(ANDROID_PLUGIN)/.gdignore
	@echo ""
	@echo "====================================================================="
	@echo "✓ Android plugin built successfully!"
	@echo "====================================================================="
	@echo ""
	@echo "Generated AARs:"
	@ls -lh $(ANDROID_OUTPUT_DIR)/$(ANDROID_PLUGIN)/*.aar 2>/dev/null || echo "  (No AARs found)"

# ============================================================================
# Combined Targets
# ============================================================================

build-all: build-apple build-android
	@echo ""
	@echo "====================================================================="
	@echo "✓✓✓ ALL PLUGINS BUILT SUCCESSFULLY! ✓✓✓"
	@echo "====================================================================="

package:
	@echo "====================================================================="
	@echo "Creating package..."
	@echo "====================================================================="
	@echo ""
	@rm -rf package
	@mkdir -p package
	@echo "→ Copying addons..."
	@cp -a $(ADDONS_SOURCE_DIR) package/
	@mkdir -p package/addons/$(PLUGIN_NAME)/bin/ios/
	@mkdir -p package/addons/$(PLUGIN_NAME)/bin/android/
	@echo "→ Copying Apple plugin..."
	@cp -a $(IOS_OUTPUT_DIR)/* package/addons/$(PLUGIN_NAME)/bin/ios/
	@echo "→ Copying Android plugin..."
	@cp -a $(ANDROID_OUTPUT_DIR)/* package/addons/$(PLUGIN_NAME)/bin/android/
	@echo "→ Creating zip archive..."
	@cd package && zip -ry ../$(PLUGIN_NAME).zip .
	@echo ""
	@echo "====================================================================="
	@echo "✓ Package created!"
	@echo "====================================================================="

# ============================================================================
# Demo Targets
# ============================================================================

demo-setup:
	@if [ ! -d "$(PACKAGE_DIR)" ]; then \
		echo "→ You need to run 'make package' first!"; \
		exit 1; \
	fi
	@echo "====================================================================="
	@echo "Setting up demo..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Removing old files..."
	@rm -rf $(DEMO_DIR)/addons
	@echo "→ Copying new files..."
	@cp -a $(PACKAGE_DIR)/* $(DEMO_DIR)/ && \
	echo "→ Demo setup complete!" && \
	echo "====================================================================="

# ============================================================================
# Clean Targets
# ============================================================================

clean:
	@echo "====================================================================="
	@echo "Cleaning build artifacts..."
	@echo "====================================================================="
	@echo ""
	@echo "→ Cleaning general files..."
	@rm -rf $(BUILD_ROOT_DIR)
	@rm -rf $(PACKAGE_DIR)
	@echo "→ Cleaning Android..."
	@if [ -d "$(ANDROID_SOURCE_DIR)" ]; then \
		(cd $(ANDROID_SOURCE_DIR) && ./gradlew clean); \
	fi
	@echo ""
	@echo "====================================================================="
	@echo "✓ Clean complete!"
	@echo "====================================================================="

clean-godot:
	@echo "====================================================================="
	@echo "Removing Godot CPP source..."
	@echo "====================================================================="
	@echo ""
	@if [ -d "$(GODOT_CPP_DIR)" ]; then \
		echo "→ Removing Godot CPP directory..."; \
		rm -rf $(GODOT_CPP_DIR); \
		echo "  ✓ Godot CPP source removed"; \
	else \
		echo "  • Godot CPP source directory does not exist"; \
	fi
	@echo ""
	@echo "====================================================================="
	@echo "✓ Done!"
	@echo "====================================================================="

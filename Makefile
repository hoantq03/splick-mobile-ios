.PHONY: generate setup clean reset-xcode open-xcode build stubs

API_STUB_PORT ?= 8080

# Generate Xcode project using XcodeGen (installs binary if needed)
generate:
	./scripts/generate-xcodeproj.sh

# Install dependencies and generate project
setup: generate
	@echo "Splick.xcodeproj ready. Open Splick.xcodeproj in Xcode."

# Clean build artifacts
clean:
	rm -rf DerivedData build
	xcodebuild clean -project Splick.xcodeproj -scheme SplickApp 2>/dev/null || true

# Reset DerivedData + SwiftPM caches (use when Xcode shows package load / dyld abort)
reset-xcode:
	chmod +x scripts/reset-xcode-packages.sh scripts/verify-xcodeproj.sh
	./scripts/reset-xcode-packages.sh

# Regenerate project and open Splick.xcodeproj (safe entry point for Xcode)
open-xcode: generate
	open "$(CURDIR)/Splick.xcodeproj"

# Build the project
build: generate
	xcodebuild build \
		-project Splick.xcodeproj \
		-scheme SplickApp \
		-destination 'platform=iOS Simulator,name=iPhone 17' \
		-configuration Debug

# Run tests
test: generate
	xcodebuild test \
		-project Splick.xcodeproj \
		-scheme SplickApp \
		-destination 'platform=iOS Simulator,name=iPhone 17' \
		-configuration Debug

# Format Swift code
format:
	swift-format format -i -r SplickApp/ Packages/

# Local mock API for simulator (requires Node.js: brew install node)
stubs:
	@if ! command -v npx >/dev/null 2>&1; then \
		echo "Error: npx not found. Install Node.js: brew install node"; \
		exit 1; \
	fi
	cd api-stubs && npx --yes json-server --watch db.json --routes routes.json --port $(API_STUB_PORT)

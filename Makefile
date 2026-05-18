.PHONY: generate setup clean build stubs

API_STUB_PORT ?= 8080

# Generate Xcode project using XcodeGen
generate:
	xcodegen generate

# Install dependencies and generate project
setup:
	brew install xcodegen || true
	$(MAKE) generate

# Clean build artifacts
clean:
	rm -rf DerivedData build
	xcodebuild clean -project Splick.xcodeproj -scheme SplickApp 2>/dev/null || true

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

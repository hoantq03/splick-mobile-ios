.PHONY: generate setup clean build

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
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-configuration Debug

# Run tests
test: generate
	xcodebuild test \
		-project Splick.xcodeproj \
		-scheme SplickApp \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-configuration Debug

# Format Swift code
format:
	swift-format format -i -r SplickApp/ Packages/

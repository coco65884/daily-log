.PHONY: generate build test lint format clean

PROJECT := DailyLog.xcodeproj
SCHEME := DailyLog
DESTINATION := platform=iOS Simulator,name=iPhone 17,OS=latest

generate:
	xcodegen generate

build: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-configuration Debug \
		build

test: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		test

lint:
	cd .. && swiftlint --config .swiftlint.yml ios

format-check:
	cd .. && swiftformat --lint --config .swiftformat ios

format:
	cd .. && swiftformat --config .swiftformat ios

clean:
	rm -rf $(PROJECT) build DerivedData

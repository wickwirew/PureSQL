.PHONY: build zip release

UNAME_S := $(shell uname -s)
BUILD_FLAGS :=
BUILD_DIR :=
OUTPUT_NAME ?= build.tar.gz

ifeq ($(UNAME_S),Darwin)
	BUILD_FLAGS := -c release --product PureSQLCLI --arch arm64 --arch x86_64
	BUILD_DIR := .build/apple/Products/Release
else
    BUILD_FLAGS := -c release --product PureSQLCLI
	BUILD_DIR := .build/release
endif

build:
	@swift build $(BUILD_FLAGS)

zip:
	cp $(BUILD_DIR)/PureSQLCLI puresql
	tar -cvzf $(OUTPUT_NAME) puresql

release: build zip

APP_NAME := scan-app
VERSION := 1.0.0
BUILD_DIR := build
SRC_DIR := src
ARTIFACT := $(BUILD_DIR)/$(APP_NAME)-$(VERSION).zip

.PHONY: all clean build

all: build

build:
	@mkdir -p $(BUILD_DIR)
	@echo "Building pseudo-binary $(ARTIFACT)"
	@cd $(SRC_DIR) && zip -r ../$(ARTIFACT) . -q
	@echo "Built $(ARTIFACT)"

clean:
	rm -rf $(BUILD_DIR)

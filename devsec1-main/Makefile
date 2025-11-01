APP_NAME := scan-app
VERSION ?= $(or $(GITHUB_REF_NAME),1.0.0)
DIST_DIR := dist
SRC_DIR := src
ARTIFACT := $(DIST_DIR)/$(APP_NAME)-$(VERSION).zip

.PHONY: all clean build sbom

all: build

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

build: $(DIST_DIR)
	@echo "Building pseudo-binary $(ARTIFACT)"
	@cd $(SRC_DIR) && zip -r ../$(ARTIFACT) . -q
	@echo "Built $(ARTIFACT)"

sbom: $(DIST_DIR)
	@echo "Generating SBOM (spdx-json)"
	@syft dir:$(SRC_DIR) -o spdx-json > $(DIST_DIR)/sbom.spdx.json
	@echo "SBOM at $(DIST_DIR)/sbom.spdx.json"

clean:
	rm -rf $(DIST_DIR)


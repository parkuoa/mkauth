OUTPUT_DIR = output
CLI = $(OUTPUT_DIR)/secmgr
CLI_SOURCES = secmgr/*.swift
SWIFT = swiftc
AUTHBUNDLE ?= AuthorizationBundle
MANAGER_CORE ?=

# manager-related
MANAGER_CORE_SRC = $(wildcard $(MANAGER_CORE)/*.swift)
MANAGER_OUTPUT = $(OUTPUT_DIR)/manager/ThemeManager.app

.PHONY: all clean cli authbundle help install

all:
	mkdir $(OUTPUT_DIR)
	/usr/bin/swiftc $(CLI_SOURCES) -o $(CLI)

$(CLI): $(CLI_SOURCES)
	/usr/bin/swiftc $(CLI_SOURCES) -o $(CLI)

cli:
	mkdir $(OUTPUT_DIR)
	/usr/bin/swiftc $(CLI_SOURCES) -o $(CLI)

authbundle: validate-authbundle
	@echo "building auth bundle from $(AUTHBUNDLE)..."
	@cd "$(AUTHBUNDLE)" && MANAGER_CORE="$(MANAGER_CORE)" /bin/bash ./build.sh

validate-authbundle:
	@if [ -z "$(AUTHBUNDLE)" ] || [ ! -d "$(AUTHBUNDLE)" ]; then \
		echo "AUTHBUNDLE must point to a valid AuthorizationBundle checkout." >&2; \
		exit 1; \
	fi
	@for f in core/LoginUI.swift core/AuthorizationPlugin.swift core/Mechanism.swift Info.plist build.sh; do \
		if [ ! -f "$(AUTHBUNDLE)/$$f" ]; then \
			echo "Missing required authbundle file: $(AUTHBUNDLE)/$$f" >&2; \
			exit 1; \
		fi; \
	done
	@if [ -n "$(MANAGER_CORE)" ] && [ ! -f "$(MANAGER_CORE)/SettingsManager.swift" ]; then \
		echo "MANAGER_CORE must point to a directory containing SettingsManager.swift." >&2; \
		exit 1; \
	fi

clean:
	rm -f $(CLI)
	rm -rf $(OUTPUT_DIR)

install:
	sudo cp $(CLI) /usr/local/bin

manager:
	@mkdir -p $(MANAGER_OUTPUT)/Contents/{MacOS,Resources}
	$(SWIFT) -target arm64-apple-macosx11.0 $(MANAGER_CORE_SRC) -o "$(MANAGER_OUTPUT)/Contents/MacOS/thememanager"

	@mkdir -p "$(MANAGER_OUTPUT)/Contents/Resources/img"
	@mkdir -p "$(MANAGER_OUTPUT)/Contents/Resources/login/BengalLogin.bundle"
	@cp $(MANAGER_CORE)/Info.plist "$(MANAGER_OUTPUT)/Contents/"
	@cp -r $(MANAGER_CORE_SRC) "$(MANAGER_OUTPUT)/Contents/MacOS/"
	@cp -r $(MANAGER_CORE)/img/* "$(MANAGER_OUTPUT)/Contents/Resources/img/"
	@cp $(MANAGER_CORE)/img/logo.icns "$(MANAGER_OUTPUT)/Contents/Resources/"
	@cp -rf $(AUTHBUNDLE)/build/BengalLogin.bundle/* "$(MANAGER_OUTPUT)/Contents/Resources/login/BengalLogin.bundle/"
	
help:
	@echo ""
	@echo "make <target>"
	@echo ""
	@echo "targets:"
	@echo "  all/cli: build cli"
	@echo "  authbundle: build auth bundle from external AuthorizationBundle checkout"
	@echo "  clean: clean cli"
	@echo "  cleanall: clean cli"
	@echo "  help: Show this help message"
	@echo ""

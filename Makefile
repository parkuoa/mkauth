OUTPUT_DIR = output
CLI = $(OUTPUT_DIR)/secmgr
CLI_SOURCES = secmgr/*.swift
SWIFT = swiftc
AUTHBUNDLE ?= AuthorizationBundle
APP_CORE ?=

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
	@cd "$(AUTHBUNDLE)" && APP_CORE="$(APP_CORE)" /bin/bash ./build.sh

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
	@if [ -n "$(APP_CORE)" ] && [ ! -f "$(APP_CORE)/SettingsManager.swift" ]; then \
		echo "APP_CORE must point to a directory containing SettingsManager.swift." >&2; \
		exit 1; \
	fi

clean:
	rm -f $(CLI)
	rmdir $(OUTPUT_DIR)

install:
	sudo cp $(CLI) /usr/local/bin

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

CLI = bengal/bengal
CLI_SOURCES = bengal/*.swift
SWIFT = swiftc
APP_NAME = bengal.app
APP_BUILDDIR= app_build
APP_BUNDLE_DIR = $(APP_BUILDDIR)/$(APP_NAME)
APP_SOURCES = app_src/*.swift
LOGIN_UI_BUILDDIR = AuthorizationBundle/build
LOGIN_UI = AuthorizationBundle/build/BengalLogin.bundle
FONTS = AuthorizationBundle/Resources/*.ttf

.PHONY: all clean* cli bundle app help

all: $(CLI) bundle app

$(CLI): $(CLI_SOURCES)
	/usr/bin/swiftc $(CLI_SOURCES) -o $(CLI)

cli:
	/usr/bin/swiftc $(CLI_SOURCES) -o $(CLI)

bundle:
	/bin/bash ./AuthorizationBundle/build.sh

app: $(CLI)
	@echo "building bengal.app..."
	@mkdir -p "$(APP_BUNDLE_DIR)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE_DIR)/Contents/Resources"
	@mkdir -p "$(APP_BUNDLE_DIR)/Contents/Resources/{img,login}"
	@mkdir -p "$(APP_BUNDLE_DIR)/Contents/Resources/login/BengalLogin.bundle"
	$(SWIFT) $(APP_SOURCES) -o "$(APP_BUNDLE_DIR)/Contents/MacOS/bengalwrapper"
	@cp app_src/Info.plist "$(APP_BUNDLE_DIR)/Contents/"
	@cp $(CLI) "$(APP_BUNDLE_DIR)/Contents/Resources/"
	@cp $(FONTS) "$(APP_BUNDLE_DIR)/Contents/Resources/"
	@cp -r app_src/img/* "$(APP_BUNDLE_DIR)/Contents/Resources/img/" 2>/dev/null || true
	@cp app_src/img/logo.icns "$(APP_BUNDLE_DIR)/Contents/Resources/" 2>/dev/null || true
	/bin/bash ./AuthorizationBundle/build.sh
	@cp -rf AuthorizationBundle/build/BengalLogin.bundle/* "$(APP_BUNDLE_DIR)/Contents/Resources/login/BengalLogin.bundle/"
	@echo "app built successfully: $(APP_BUNDLE_DIR)"

clean:
	rm -f $(CLI)

cleanbundle:
	rm -rf $(LOGIN_UI_BUILDDIR)

cleanapp:
	rm -rf $(APP_BUILDDIR)

cleanall:
	rm -rf $(CLI) $(LOGIN_UI_BUILDDIR) $(APP_BUILDDIR)

help:
	@echo ""
	@echo "make <target>"
	@echo ""
	@echo "targets:"
	@echo "  all: build cli, bundle and app"
	@echo "  cli: build cli"
	@echo "  bundle: build plugin/auth bundle"
	@echo "  app: build app"
	@echo "  clean: clean cli"
	@echo "  cleanbundle: clean plugin/auth bundle"
	@echo "  cleanapp: clean app"
	@echo "  cleanall: clean all"
	@echo "  help: Show this help message"
	@echo ""
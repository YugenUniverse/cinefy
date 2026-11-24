# Cinefy: convenience wrapper around CMake.
#
#   make                 optimised release build (configures on first run)
#   make run             build and start (EXPORT=path/to/export.zip to open one)
#   make debug           development build with debug info, in build-debug/
#   make install         install to ~/.local (PREFIX=/usr/local to change; may need sudo)
#   make uninstall       remove what `make install` put there
#   make test            check the export parser (needs EXPORT=...)
#   make clean           remove build outputs, keep configuration
#   make distclean       remove the whole build directory
#   make deps            show the packages to install (Arch, Debian/Ubuntu, Fedora, openSUSE, macOS)
#
# Works on Linux and macOS. On Windows use CMake directly (see README).

BUILD_DIR  ?= build
BUILD_TYPE ?= Release
PREFIX     ?= $(HOME)/.local
JOBS       ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
UNAME      := $(shell uname -s)
ifeq ($(UNAME),Darwin)
  APP := $(BUILD_DIR)/cinefy.app/Contents/MacOS/cinefy
else
  APP := $(BUILD_DIR)/cinefy
endif
EXPORT     ?=
GENERATOR  := $(shell command -v ninja >/dev/null 2>&1 && echo Ninja || echo "Unix Makefiles")

.PHONY: all build debug run test install uninstall clean distclean deps help

all: build

$(BUILD_DIR)/CMakeCache.txt:
	cmake -S . -B $(BUILD_DIR) -G "$(GENERATOR)" \
	      -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
	      $(if $(CMAKE_PREFIX_PATH),-DCMAKE_PREFIX_PATH=$(CMAKE_PREFIX_PATH))

build: $(BUILD_DIR)/CMakeCache.txt
	cmake --build $(BUILD_DIR) -j $(JOBS)

debug:
	$(MAKE) build BUILD_DIR=build-debug BUILD_TYPE=RelWithDebInfo

run: build
	./$(APP) $(EXPORT)

test: build
	@test -n "$(EXPORT)" || { echo "usage: make test EXPORT=path/to/letterboxd-export.zip"; exit 2; }
	./$(BUILD_DIR)/cinefy_loadtest "$(EXPORT)"

install: build
	cmake --install $(BUILD_DIR) --prefix "$(PREFIX)" --strip
	@echo "Installed to $(PREFIX)."

uninstall:
	rm -f "$(PREFIX)/bin/cinefy" \
	      "$(PREFIX)/share/applications/cinefy.desktop" \
	      "$(PREFIX)/share/icons/hicolor/scalable/apps/cinefy.svg"

clean:
	@if [ -d $(BUILD_DIR) ]; then cmake --build $(BUILD_DIR) --target clean; fi

distclean:
	rm -rf $(BUILD_DIR)

deps:
	@if command -v pacman >/dev/null 2>&1; then \
	  echo "sudo pacman -S --needed qt6-base qt6-declarative qt6-quick3d qt6-shadertools qt6-multimedia qt6-multimedia-ffmpeg cmake ninja"; \
	elif command -v apt-get >/dev/null 2>&1; then \
	  echo "sudo apt install cmake ninja-build qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev qt6-quick3d-dev qt6-quick3d-dev-tools qt6-shadertools-dev qt6-multimedia-dev"; \
	  echo "(needs Qt 6.8+: Ubuntu 25.04 / Debian 13 or newer, otherwise use the Qt online installer)"; \
	elif command -v dnf >/dev/null 2>&1; then \
	  echo "sudo dnf install cmake ninja-build qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtquick3d-devel qt6-qtshadertools-devel qt6-qtmultimedia-devel"; \
	elif command -v zypper >/dev/null 2>&1; then \
	  echo "sudo zypper install cmake ninja qt6-base-devel qt6-base-private-devel qt6-declarative-devel qt6-quick3d-devel qt6-shadertools-devel qt6-multimedia-devel"; \
	elif command -v brew >/dev/null 2>&1; then \
	  echo "brew install qt cmake ninja"; \
	else \
	  echo "Install Qt 6.8+ (with Qt Quick 3D, Qt Multimedia, Qt Shader Tools) from https://www.qt.io/download and CMake."; \
	fi

help:
	@sed -n '1,13p' Makefile

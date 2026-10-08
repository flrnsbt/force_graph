FVM_STANDALONE=$(HOME)/fvm/bin/fvm
GET_FVM= $$(command -v fvm 2>/dev/null || echo "$(FVM_STANDALONE)")
BUILD_NUM := $(shell date +%Y%m%d.%H%M%S)

FLUTTER_APP_PATH := example/

ensure-fvm:
	@if command -v fvm >/dev/null 2>&1; then \
		echo "✓ FVM detected in global PATH."; \
	elif [ -x "$(FVM_STANDALONE)" ]; then \
		echo "✓ FVM detected at standalone path: $(FVM_STANDALONE)"; \
	else \
		echo "⚠️ FVM not found. Downloading via official install script..."; \
		curl -fsSL https://fvm.app/install.sh | bash; \
	fi
	@echo "Synchronizing project Flutter SDK version..."
	@$(GET_FVM) install


clean: ensure-fvm
	@echo "Cleaning project space..."	
	@cd $(FLUTTER_APP_PATH) && $(GET_FVM) flutter clean && $(GET_FVM) flutter pub get --enforce-lockfile

build-ci: clean
	@cd $(FLUTTER_APP_PATH) && $(GET_FVM) flutter build web \
		--wasm \
		--no-pub \
		--no-web-resources-cdn \
		--optimization-level=4 \
		--dart-define=BUILD_NUMBER=$(BUILD_NUM) \
		--web-define=BUILD_NUMBER=$(BUILD_NUM) \
		--tree-shake-icons \
		--no-source-maps \
		--strip-wasm
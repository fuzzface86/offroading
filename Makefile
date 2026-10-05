# Needs the Playdate SDK (PLAYDATE_SDK_PATH set, pdc on PATH) for build/run. `make test` needs plain Lua 5.4.
PDX = offroading.pdx

.PHONY: build run test
build:
	pdc source $(PDX)
run: build
	$(PLAYDATE_SDK_PATH)/bin/PlaydateSimulator $(PDX)
test:
	lua tests/run.lua
	lua tests/render_smoke.lua

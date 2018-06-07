.PHONY: run install-deps

run: local
	@bin/send_report

local:
	@carton install --deployment

install-deps:
	@carton install

info:
	@echo try make serve

serve:
	opencode serve --mdns --mdns-domain opencode-yolo1.lan --port 34189 &

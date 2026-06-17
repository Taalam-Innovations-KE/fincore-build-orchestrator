# FinCore platform orchestration.
#
# Thin wrappers around ./fincore (the bash entrypoint that validates env files,
# creates the network, and brings the stack up). Run `./fincore help` for detail.
#
#   make init         create missing .env files from templates
#   make up-local     validate + bring the stack up for local development
#   make up-prod      validate + bring the stack up for production (Traefik + TLS)
#   make check-prod   validate prod config without starting anything
#   make down         stop and remove the stack
#   make ps / logs    inspect running services
#   make pull         pull the latest images

.PHONY: init up-local up-prod check-local check-prod down down-prod ps logs pull

init:
	./fincore init

up-local:
	./fincore up local

up-prod:
	./fincore up prod

check-local:
	./fincore check local

check-prod:
	./fincore check prod

down:
	./fincore down local

down-prod:
	./fincore down prod

ps:
	./fincore ps local

logs:
	./fincore logs

pull:
	./fincore pull
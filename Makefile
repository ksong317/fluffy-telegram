.DEFAULT_GOAL := help
.PHONY: help bootstrap generate open lint test db-start db-push db-reset db-diff

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install dev tools (xcodegen, swiftlint, supabase) + create local secrets + generate
	./scripts/bootstrap.sh

generate: ## Generate Shotgun.xcodeproj from project.yml
	xcodegen generate

open: generate ## Generate the project and open it in Xcode
	open Shotgun.xcodeproj

lint: ## Run SwiftLint
	swiftlint

test: ## Run unit tests on a simulator
	xcodebuild test \
		-project Shotgun.xcodeproj \
		-scheme Shotgun \
		-destination 'platform=iOS Simulator,name=iPhone 16'

db-start: ## Start the local Supabase stack (Docker)
	supabase start

db-push: ## Apply migrations to the linked remote project
	supabase db push

db-reset: ## Reset the LOCAL database and replay all migrations
	supabase db reset

db-diff: ## Diff local schema against migrations (name it: make db-diff NAME=add_x)
	supabase db diff -f $(NAME)

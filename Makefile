.PHONY: bump check

PLUGIN_JSON := .claude-plugin/plugin.json
MARKETPLACE_JSON := .claude-plugin/marketplace.json

bump:
	@current=$$(jq -r '.version' $(PLUGIN_JSON)); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	patch=$$(echo $$current | cut -d. -f3); \
	new_patch=$$((patch + 1)); \
	new_version="$$major.$$minor.$$new_patch"; \
	jq --arg v "$$new_version" '.version = $$v' $(PLUGIN_JSON) > tmp.json && mv tmp.json $(PLUGIN_JSON); \
	jq --arg v "$$new_version" '.metadata.version = $$v | .plugins[0].version = $$v' $(MARKETPLACE_JSON) > tmp.json && mv tmp.json $(MARKETPLACE_JSON); \
	for f in skills/*/SKILL.md; do sed -i "s/v$$current/v$$new_version/" "$$f"; done; \
	for f in skills/*/SKILL.md; do sed -i "s/^  version: $$current$$/  version: $$new_version/" "$$f"; done; \
	echo "Bumped version: $$current -> $$new_version"

check:
	npx skill-check .

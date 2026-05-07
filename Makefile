.PHONY: bump check check-version-sync

PLUGIN_JSON := .claude-plugin/plugin.json
MARKETPLACE_JSON := .claude-plugin/marketplace.json

bump: check-version-sync
	@current=$$(jq -r '.version' $(PLUGIN_JSON)); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	patch=$$(echo $$current | cut -d. -f3); \
	new_patch=$$((patch + 1)); \
	new_version="$$major.$$minor.$$new_patch"; \
	jq --arg v "$$new_version" '.version = $$v' $(PLUGIN_JSON) > tmp.json && mv tmp.json $(PLUGIN_JSON); \
	jq --arg v "$$new_version" '.metadata.version = $$v | .plugins[0].version = $$v' $(MARKETPLACE_JSON) > tmp.json && mv tmp.json $(MARKETPLACE_JSON); \
	echo "Bumped version: $$current -> $$new_version"

check-version-sync:
	@plugin_v=$$(jq -r '.version' $(PLUGIN_JSON)); \
	mp_meta_v=$$(jq -r '.metadata.version' $(MARKETPLACE_JSON)); \
	mp_plugin_v=$$(jq -r '.plugins[0].version' $(MARKETPLACE_JSON)); \
	if [ "$$plugin_v" != "$$mp_meta_v" ] || [ "$$plugin_v" != "$$mp_plugin_v" ]; then \
		echo "error: version drift detected"; \
		echo "  $(PLUGIN_JSON) .version             = $$plugin_v"; \
		echo "  $(MARKETPLACE_JSON) .metadata.version    = $$mp_meta_v"; \
		echo "  $(MARKETPLACE_JSON) .plugins[0].version  = $$mp_plugin_v"; \
		echo "sync all three to the same value, then re-run make bump"; \
		exit 1; \
	fi

check:
	./scripts/check-references-indexed.sh
	npx skill-check .

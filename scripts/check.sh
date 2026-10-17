#!/usr/bin/env bash
# Runs every check: StyLua formatting, selene lint, luau-lsp type checking with the new type solver,
# and the test suite. Exits non-zero if any check fails. Run from anywhere:
#   bash scripts/check.sh

set -uo pipefail
cd "$(dirname "$0")/.."

# Roblox API types for luau-lsp. Cached in the ignored build folder and refreshed once a day; the
# cached copy is used when offline.
DEFINITIONS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
DEFINITIONS="build/luau-lsp/globalTypes.d.luau"
SOURCES=(src test bench .lune)

failed=0

# Runs a named check and records a failure without stopping the remaining checks.
run() {
	local name="$1"
	shift
	echo "== $name"
	if "$@"; then
		echo "ok"
	else
		echo "FAILED: $name"
		failed=1
	fi
}

# Downloads the Roblox definitions when missing or older than a day.
fetch_definitions() {
	mkdir -p "$(dirname "$DEFINITIONS")"
	if [[ -f "$DEFINITIONS" && -z "$(find "$DEFINITIONS" -mtime +0)" ]]; then
		return 0
	fi
	if curl -fsSL "$DEFINITIONS_URL" -o "$DEFINITIONS.tmp"; then
		mv "$DEFINITIONS.tmp" "$DEFINITIONS"
	elif [[ -f "$DEFINITIONS" ]]; then
		echo "Couldn't refresh Roblox definitions; using the cached copy."
	else
		echo "Couldn't download Roblox definitions from $DEFINITIONS_URL"
		return 1
	fi
}

# Type checks with the new solver. Lune's type definitions back the `@lune` alias in .luaurc.
analyze() {
	lune setup >/dev/null || return 1
	local output status
	output="$(luau-lsp analyze \
		--platform=roblox \
		--definitions=@roblox="$DEFINITIONS" \
		--flag:LuauSolverV2=true \
		"${SOURCES[@]}" 2>&1)"
	status=$?
	grep -v -E '^\[(INFO|WARN)\]' <<<"$output"
	return "$status"
}

run "StyLua" stylua --check "${SOURCES[@]}"
run "selene" selene "${SOURCES[@]}"

if fetch_definitions; then
	run "luau-lsp" analyze
else
	echo "FAILED: luau-lsp setup"
	failed=1
fi

run "tests" lune run test

exit "$failed"

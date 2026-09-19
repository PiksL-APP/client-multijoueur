class_name Version
extends RefCounted
## ÉCRIT PAR le workflow d'export — ne pas modifier à la main.

const COMMIT := "fe821a4"
const DATE := "19/09/2026 14:18 UTC"

static func etiquette() -> String:
	if COMMIT == "sources":
		return "sources (non exporté)"
	return "%s · %s" % [COMMIT, DATE]

class_name Version
extends RefCounted
## ÉCRIT PAR le workflow d'export — ne pas modifier à la main.

const COMMIT := "278b22c"
const DATE := "17/09/2026 10:54 UTC"

static func etiquette() -> String:
	if COMMIT == "sources":
		return "sources (non exporté)"
	return "%s · %s" % [COMMIT, DATE]

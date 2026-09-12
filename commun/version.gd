class_name Version
extends RefCounted
## ÉCRIT PAR le workflow d'export — ne pas modifier à la main.

const COMMIT := "0edb43d"
const DATE := "11/09/2026 19:50 UTC"

static func etiquette() -> String:
	if COMMIT == "sources":
		return "sources (non exporté)"
	return "%s · %s" % [COMMIT, DATE]

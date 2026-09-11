class_name Version
extends RefCounted
## ÉCRIT PAR le workflow d'export — ne pas modifier à la main.

const COMMIT := "65b0b9d"
const DATE := "11/09/2026 17:25 UTC"

static func etiquette() -> String:
	if COMMIT == "sources":
		return "sources (non exporté)"
	return "%s · %s" % [COMMIT, DATE]

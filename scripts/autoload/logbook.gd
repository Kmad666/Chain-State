extends Node
## The Agent's logbook (autoload "Logbook").
##
## Two parts:
##   - the field guide: what each school of magic leaves behind at a crime
##     scene, loaded from data/magic_schools.json (edit that file to change it)
##   - case evidence: the clues the Agent has examined, in the order found
##
## Evidence entry: {id, school, title, note, where}

signal evidence_added(entry: Dictionary)

const SCHOOLS_PATH := "res://data/magic_schools.json"

var schools: Array = []        # [{id, name, color, lens, summary, evidence: [{sign, means}], mistaken_for}]
var general: Array = []        # general notes shown on the guide's first page
var evidence: Array = []       # collected entries, oldest first


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SCHOOLS_PATH))
	if parsed is Dictionary:
		schools = parsed.get("schools", [])
		general = parsed.get("general", [])
	else:
		push_error("Couldn't read %s" % SCHOOLS_PATH)


func school(id: String) -> Dictionary:
	for s in schools:
		if s.id == id:
			return s
	return {}


func has_evidence(id: String) -> bool:
	return evidence.any(func(e): return e.id == id)


## Adds a clue to the logbook. Returns false if it was already logged.
func add_evidence(entry: Dictionary) -> bool:
	if has_evidence(str(entry.get("id", ""))):
		return false
	evidence.append(entry)
	evidence_added.emit(entry)
	return true


func clear() -> void:
	evidence.clear()

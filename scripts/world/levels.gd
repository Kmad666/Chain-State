class_name Levels
## The levels the level select offers, in order. `build` names the function in
## world.gd that lays the level out.

const LIST := [
	{"id": "range", "name": "Test Range", "blurb": "Flat plane, one floating cube, an NPC and four practice clues."},
	{"id": "level_1", "name": "Level 1", "blurb": "Two floating islands, level with each other. Learn to cross the gap."},
	{"id": "level_2", "name": "Level 2", "blurb": "Two floating islands, the far one wider apart and higher up."},
	{"id": "enemy_test", "name": "Enemy Test", "blurb": "Two Sentries patrol around an island. Dodge the volleys, hook one up close and swing around it."},
]


static func info(id: String) -> Dictionary:
	for l in LIST:
		if l.id == id:
			return l
	return LIST[0]

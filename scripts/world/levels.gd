class_name Levels
## The levels the level select offers, in order. `build` names the function in
## world.gd that lays the level out.

const LIST := [
	{"id": "range", "name": "Test Range", "blurb": "Flat plane, one floating cube, an NPC and four practice clues."},
	{"id": "level_1", "name": "Level 1", "blurb": "Two floating islands, level with each other. Learn to cross the gap."},
	{"id": "level_2", "name": "Level 2", "blurb": "Two floating islands, the far one wider apart and higher up."},
	{"id": "enemy_test", "name": "Enemy Test (Ground)", "blurb": "One low Sentry. Get close and it fires lines of orbs across the ground. Hook it and swing around it."},
	{"id": "enemy_test_air", "name": "Enemy Test (Air)", "blurb": "One high Sentry inside a spinning ring of red orbs. Grab the blue orbs to get close."},
]


static func info(id: String) -> Dictionary:
	for l in LIST:
		if l.id == id:
			return l
	return LIST[0]

class_name Levels
## The levels the level select offers, in order. `build` names the function in
## world.gd that lays the level out.

const LIST := [
	{"id": "range", "name": "Test Range", "blurb": "Flat plane, one floating cube, an NPC and four practice clues."},
	{"id": "level_1", "name": "Level 1", "blurb": "Two floating islands, level with each other. Learn to cross the gap."},
	{"id": "level_2", "name": "Level 2", "blurb": "Two floating islands, the far one wider apart and higher up."},
	{"id": "platform_test", "name": "Platform Test", "blurb": "Grass blocks over the void: you land on them but can't grapple them. Swing from the crates. Cross every gap in as few swings as you can."},
	{"id": "enemy_test", "name": "Enemy Test (Ground)", "blurb": "A wizard on a broom, flying low. Get close and he fires lines of orbs across the ground. Hook him and swing around."},
	{"id": "enemy_test_air", "name": "Enemy Test (Air)", "blurb": "The witch's tree: climb a slowly turning cone of red orbs using the blue ones, then get inside her ward."},
]


static func info(id: String) -> Dictionary:
	for l in LIST:
		if l.id == id:
			return l
	return LIST[0]

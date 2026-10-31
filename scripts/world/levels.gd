class_name Levels
## The levels the level select offers, in order. `build` names the function in
## world.gd that lays the level out.

const LIST := [
	{"id": "range", "name": "Test Range", "blurb": "Flat plane, one floating cube, an NPC and four practice clues."},
	{"id": "level_1", "name": "Level 1", "blurb": "Two floating islands, level with each other. Learn to cross the gap."},
	{"id": "level_2", "name": "Level 2", "blurb": "Two floating islands, the far one wider apart and higher up."},
	{"id": "nation", "name": "The Nation (draft)", "blurb": "The whole Gordian Empire at 1:50, blocked out from the casebook map: Delos (1 km) in the middle, the five state capitals 4 to 7 km out, their satellite isles and twelve ordinary islands between. Press F4 or V to fly (Shift = fast)."},
	{"id": "spire_town", "name": "Spire Town", "blurb": "A town on two rock pillars rising out of the clouds: a palace and towers on one, pastel houses spiralling up the other, joined by a viaduct, a rock arch and a plank bridge. Climb to the heights; the highest place you've stood is your checkpoint."},
	{"id": "cloud_tree", "name": "The Cloud Tree", "blurb": "A vast pale tree on a meadow island, its leaves made of clouds. Climb the bark, then swing cloud to cloud: the big puffs are solid and free to grapple. Highest place you've stood is your checkpoint."},
	{"id": "platform_test", "name": "Platform Test", "blurb": "Grass blocks over the void: you land on them but can't grapple them. Swing from the crates. Cross every gap in as few swings as you can."},
	{"id": "hamlet", "name": "Hamlet", "blurb": "A small hamlet on a floating island. Walk the lanes or swing between rooftop anchors; a house has burnt from the inside. Talk to the locals and find the clues."},
	{"id": "city", "name": "City", "blurb": "A dense city island: five-storey stone terraces wall to wall, cobbled streets, alleys and a fountain plaza. Swing between the anchors over the crossroads."},
	{"id": "ascent", "name": "The Ascent", "blurb": "A great forest island and 50 anchors spiralling up round its giant tree to a finish platform 400 m in the sky. Anchors are free: chain them all. Five apprentices shoot at you on the way; one wrap arrests each. Rest ledges every 10."},
	{"id": "tower", "name": "Tower", "blurb": "A 130 m stone tower with grapple hooks jutting from every storey, a quarter-turn apart. Climb it hook to hook, rest on its ledges, stand on its crown."},
	{"id": "cherub_test", "name": "Cherub Test", "blurb": "A giant winged eye. Get close and it traps you in a vast cone and fills it with bullets. Grapple and arrest its Sages (5) to bring it down."},
	{"id": "enemy_test", "name": "Enemy Test (Ground)", "blurb": "A wizard on a broom, flying low. Get close and he fires lines of orbs across the ground. Hook him and swing around."},
]


static func info(id: String) -> Dictionary:
	for l in LIST:
		if l.id == id:
			return l
	return LIST[0]

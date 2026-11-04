class_name Skies
## The skies a level can be lit by (world.gd), shared with the lightmap baker
## (tools/make_bake_scenes.gd).

const DEFAULT := "ultramarine"

## Kenney "Skyboxes" (CC0): 360-degree panoramas. `u` and `elev` locate the painted
## sun in the image so the real light comes from the same place.
const LIST := {
	## The Sea Wall's look, used everywhere by default: a procedural deep-blue sky
	## (no panorama), hard bright sun, filmic tonemap with colours pushed up.
	"ultramarine": {"name": "Ultramarine", "procedural": true, "top": Color(0.02, 0.07, 0.36), "horizon": Color(0.36, 0.50, 0.82),
		"glare": 0.5, "u": 1.0 / 6.0, "elev": 52.0, "light": Color(1.0, 0.97, 0.90), "energy": 1.1,
		"ambient": 0.55, "ambient_col": Color(0.62, 0.70, 0.92), "fog": Color(0.40, 0.54, 0.84)},
	"day": {"name": "Day", "top": Color(0.548, 0.718, 0.942), "glare": 1.0, "u": 0.916, "elev": 49.9, "light": Color(1.0, 0.97, 0.90), "energy": 0.8,
		"ambient": 0.45, "fog": Color(0.685, 0.766, 0.949)},
	"morning": {"name": "Morning", "top": Color(0.992, 0.929, 0.84), "glare": 1.0, "u": 0.912, "elev": 51.3, "light": Color(1.0, 0.84, 0.66), "energy": 0.75,
		"ambient": 0.45, "fog": Color(0.977, 0.874, 0.765)},
	"night": {"name": "Night", "top": Color(0.194, 0.248, 0.451), "glare": 0.35, "u": 0.916, "elev": 51.3, "light": Color(0.62, 0.72, 1.0), "energy": 0.35,
		"ambient": 1.7, "fog": Color(0.179, 0.229, 0.407)},
	"space": {"name": "Space", "top": Color(0.099, 0.157, 0.322), "glare": 0.15, "u": 0.623, "elev": 9.1, "light": Color(0.72, 0.76, 1.0), "energy": 0.35,
		"ambient": 1.9, "fog": Color(0.143, 0.181, 0.381)},
	"alien": {"name": "Alien", "top": Color(0.853, 0.714, 0.951), "glare": 1.0, "u": 0.889, "elev": 62.6, "light": Color(1.0, 0.86, 1.0), "energy": 0.8,
		"ambient": 0.45, "fog": Color(0.843, 0.777, 0.914)},
}

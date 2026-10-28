// Mirror-polished metal (the silver chain, arrowhead and cuff).
// The Compatibility renderer only reflects the sky, which is bright in every
// direction, so plain metal looks milky. This fakes a full environment instead:
// bright sky above, a sharp horizon line, darker ground below, so the facets of
// each link flash between light and dark the way polished silver does.
// test_range.gd sets the env colours to match the current sky.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.93, 0.95, 0.99);
uniform vec3 env_top : source_color = vec3(0.55, 0.72, 0.94);
uniform vec3 env_horizon : source_color = vec3(0.69, 0.77, 0.95);
uniform vec3 env_ground : source_color = vec3(0.10, 0.11, 0.09);
uniform float strength = 1.0;

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	float y = r.y;
	vec3 sky = mix(env_horizon, env_top, pow(clamp(y, 0.0, 1.0), 0.6));
	vec3 ground = mix(env_horizon * 0.6, env_ground, smoothstep(0.0, 0.2, -y));
	vec3 env = y > 0.0 ? sky : ground;
	env += env_horizon * 0.6 * exp(-abs(y) * 60.0);           // bright horizon line
	float lum = dot(env, vec3(0.299, 0.587, 0.114));
	env = mix(env, vec3(lum), 0.35);                          // silver, not tinted glass
	float fres = 0.65 + 0.35 * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	ALBEDO = tint * 0.3;   // keep the renderer's own sky reflection low so it doesn't wash out
	METALLIC = 1.0;
	ROUGHNESS = 0.06;
	SPECULAR = 1.0;
	EMISSION = env * tint * fres * strength;
}

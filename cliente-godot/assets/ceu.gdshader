shader_type sky;
// Céu do Valtheria: degradê do dia, sol, e à noite lua com crateras, estrelas que cintilam e a faixa da via láctea.

uniform vec3 top_color : source_color = vec3(0.18, 0.36, 0.68);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.8, 0.88);
uniform vec3 ground_color : source_color = vec3(0.12, 0.14, 0.12);
uniform float night = 0.0;       // 0 dia, 1 noite fechada
uniform float cloud_cover = 0.0; // chuva: esconde estrelas e lua
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;
	vec3 col;
	if (up >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(up, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-up * 3.0, 0.0, 1.0));
	}
	float clear = 1.0 - cloud_cover;
	vec3 L = normalize(LIGHT0_DIRECTION);
	float c = dot(d, L);
	if (!AT_CUBEMAP_PASS && up > -0.05) {
		// sol (de dia) com halo
		float day = 1.0 - night;
		col += sun_color * day * clear * (smoothstep(0.9994, 0.9997, c) * 6.0 + pow(max(c, 0.0), 180.0) * 0.6 + pow(max(c, 0.0), 12.0) * 0.12);
		// noite: estrelas, via láctea e lua
		if (night > 0.01) {
			float vis = night * clear * smoothstep(-0.02, 0.18, up);
			vec3 g = d * 220.0;
			vec3 cell = floor(g);
			float h = hash(cell);
			float star = 0.0;
			if (h > 0.985) {
				vec3 sp = cell + 0.5 + (vec3(hash(cell + 3.1), hash(cell + 7.7), hash(cell + 1.9)) - 0.5) * 0.6;
				float dist = length(g - sp);
				float tw = 0.65 + 0.35 * sin(TIME * (1.5 + h * 6.0) + h * 40.0);
				star = smoothstep(0.42, 0.0, dist) * (h - 0.985) * 66.0 * tw;
			}
			vec3 star_col = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.9, 0.75), hash(cell + 11.0));
			// faixa da via láctea: um grande círculo inclinado
			vec3 band_n = normalize(vec3(0.35, 0.45, 0.82));
			float band = exp(-pow(dot(d, band_n) * 6.0, 2.0));
			float dust = band > 0.04 ? fbm(d * 9.0) * band : 0.0;
			col += (star_col * star + vec3(0.32, 0.36, 0.5) * dust * 0.45) * vis;
			// lua: disco com crateras e brilho em volta
			float moon = smoothstep(0.99955, 0.99975, c);
			if (moon > 0.0) {
				vec3 mt = (d - L) * 900.0;
				float crater = fbm(mt * 0.9 + 5.0);
				vec3 mc = vec3(0.92, 0.94, 1.0) * (0.72 + 0.4 * crater);
				col = mix(col, mc * 1.6, moon * night * (0.4 + 0.6 * clear));
			}
			col += vec3(0.55, 0.62, 0.85) * pow(max(c, 0.0), 300.0) * 0.5 * night * clear;
			col += vec3(0.3, 0.36, 0.55) * pow(max(c, 0.0), 18.0) * 0.12 * night * clear;
		}
	}
	COLOR = col;
}

shader_type canvas_item;

uniform float time;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// Random int between 0 and 1
float rint(float x) {
    return step(0.5, fract(sin(x) * 43758.5453));
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // Strong static noise - super jittery
    float static_noise = (rand(uv * time * 600.0) - 0.5) * 1.0;

    // Big chromatic aberration shift that oscillates fast
    float shift = 0.04 + 0.03 * sin(time * 30.0);
    vec2 redUV = uv + vec2(shift, 0.0);
    vec2 greenUV = uv;
    vec2 blueUV = uv - vec2(shift, 0.0);

    // Intense scanline flicker
    float scanline = sin((uv.y * 1600.0) + time * 300.0) * 0.3;

    // Strong horizontal jitter + vertical glitch lines
    float jitter = sin(uv.y * 200.0 + time * 160.0) * 0.025;
    redUV.x += jitter;
    greenUV.x += jitter;
    blueUV.x += jitter;

    // Vertical glitch displacement: sudden jumps every few frames
    float glitch = step(0.8, fract(time * 5.0)) * 0.1 * rint(floor(time * 10.0) + uv.y * 50.0);
    redUV.y += glitch;
    greenUV.y += glitch;
    blueUV.y += glitch;

    // Sample screen texture with displaced UVs
    float r = textureLod(SCREEN_TEXTURE, redUV, 0.0).r;
    float g = textureLod(SCREEN_TEXTURE, greenUV, 0.0).g;
    float b = textureLod(SCREEN_TEXTURE, blueUV, 0.0).b;

    vec3 color = vec3(r, g, b);

    // Add noise and scanline flicker
    color += static_noise + scanline;

    // Stronger desaturation for old VHS feel
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color, vec3(gray), 0.5);

    color = clamp(color, 0.0, 1.0);

    COLOR = vec4(color, 1.0);
}

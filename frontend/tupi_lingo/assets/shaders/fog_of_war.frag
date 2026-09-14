#include <flutter/runtime_effect.glsl>

// Uniforms injected from Flutter FragmentShader
uniform vec2 uResolution;       // Screen dimensions (width, height)
uniform float uTime;           // Elapsed time in seconds
uniform vec4 uFogColor;        // Base fog color (mystical deep indigo / smoke)
uniform float uNoiseScale;     // Turbulence frequency scale

out vec4 fragColor;

// 2D pseudo-random hash
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D smooth noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractional Brownian Motion (fBm) 3 octaves for drifting volumetric mist
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 3; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 coord = FlutterFragCoord().xy;
    vec2 uv = coord / uResolution;

    // Drifting coordinate for misty air currents
    vec2 mistCoord = coord * (uNoiseScale > 0.0 ? uNoiseScale : 0.0035);
    mistCoord += vec2(uTime * 0.015, sin(uTime * 0.02) * 0.01);

    float n = fbm(mistCoord);

    // Dynamic density variation
    float density = smoothstep(0.2, 0.8, n);
    float alpha = uFogColor.a * (0.65 + 0.35 * density);

    // Subtle ethereal glow variation in the mist
    vec3 mistRgb = mix(uFogColor.rgb, uFogColor.rgb * 1.35, density * 0.4);

    fragColor = vec4(mistRgb * alpha, alpha);
}

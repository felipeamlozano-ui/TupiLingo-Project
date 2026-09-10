#include <flutter/runtime_effect.glsl>

// Uniforms injetados via Dart FragmentShader.setFloat()
uniform vec2 uResolution;      // Dimensões do canvas (largura, altura)
uniform float uTime;          // Tempo decorrido em segundos
uniform vec4 uColorInner;     // Cor interna do núcleo de energia (RGBA normalizado)
uniform vec4 uColorOuter;     // Cor externa da aura ancestral (RGBA normalizado)

out vec4 fragColor;

void main() {
    // Coordenada do fragmento normalizada com suporte a Impeller / SkSL
    vec2 coord = FlutterFragCoord().xy;
    vec2 uv = (coord - 0.5 * uResolution) / min(uResolution.x, uResolution.y);
    
    // Distância radial do centro e ângulo polar
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);
    
    // 1. Harmônicos de ressonância mística (calculados em paralelo na GPU)
    float wave1 = sin(angle * 6.0 + uTime * 2.2) * 0.035;
    float wave2 = sin(angle * 10.0 - uTime * 3.4) * 0.018;
    float wave3 = cos(dist * 24.0 - uTime * 3.0) * 0.025;
    
    float deformedDist = dist + wave1 + wave2 + wave3;
    
    // 2. Halo de energia volumétrico com decaimento exponencial suave
    float glow = 0.16 / (abs(deformedDist - 0.28) + 0.07);
    glow = clamp(glow, 0.0, 2.0);
    
    // 3. Pulsação biológica suave (respiração da floresta)
    float pulse = 0.92 + 0.08 * sin(uTime * 1.8);
    glow *= pulse;
    
    // 4. Gradiente térmico / etéreo (Terracota Ancestral -> Ouro Solar Marajoara)
    vec4 color = mix(uColorInner, uColorOuter, smoothstep(0.12, 0.42, dist));
    
    // 5. Suavização das bordas externas (Zero Clipping)
    float edgeFade = smoothstep(0.52, 0.22, dist);
    float finalAlpha = clamp(glow * edgeFade, 0.0, 1.0) * color.a;
    
    fragColor = vec4(color.rgb * glow, finalAlpha);
}

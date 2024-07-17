// multicoloured blocklight code from BSL
// https://bitslablab.com/bslshaders/

const bool colortex12MipmapEnabled = true;

#define COLORED_BLOCKLIGHT

vec2 reproject(vec3 pos) {
	pos = pos * 2.0 - 1.0;

	vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
	viewPosPrev /= viewPosPrev.w;
	viewPosPrev = gbufferModelViewInverse * viewPosPrev;

	vec3 cameraOffset = cameraPosition - previousCameraPosition;
	cameraOffset *= float(pos.z > 0.56);

	vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
}

#ifdef composite0
  //Dithering from Jodie
  float bayer2(vec2 a) {
      a = floor(a);
      return fract(a.x * 0.5 + a.y * a.y * 0.75);
  }

  #define bayer4(a) (bayer2(a * 0.5) * 0.25 + bayer2(a))
  #define bayer8(a) (bayer4(a * 0.5) * 0.25 + bayer2(a))

  vec2 randDist(float x) {
    float n = fract(x * 8.0) * 6.283;
      return vec2(cos(n), sin(n)) * x * x;
  }

  float linearizeDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
  }

  vec3 calculateColoredBlockLight(vec2 coord, float z, float dither) {
    vec2 prevCoord = reproject(vec3(coord, z));
    float lz = linearizeDepth(z);

    float distScale = clamp((far - near) * lz + near, 4.0, 128.0);
    float fovScale = gbufferProjection[1][1] / 1.37;

    vec2 blurStrength = vec2(1.0 / aspectRatio, 1.0) * 2.5 * fovScale / distScale;
    
    vec3 lightAlbedo = texture2D(colortex11, coord).rgb;
    vec3 previousColoredLight = vec3(0.0);

    float mask = clamp(2.0 - 2.0 * max(abs(prevCoord.x - 0.5), abs(prevCoord.y - 0.5)), 0.0, 1.0);

    for(int i = 0; i < 4; i++) {
      vec2 offset = randDist((dither + i) * 0.25) * blurStrength;
      offset = floor(offset * vec2(viewWidth, viewHeight) + 0.5) / vec2(viewWidth, viewHeight);

      vec2 sampleZPos = coord + offset;
      float sampleZ0 = texture2D(depthtex0, sampleZPos).r;
      float sampleZ1 = texture2D(depthtex1, sampleZPos).r;
      float linearSampleZ = linearizeDepth(sampleZ1 >= 1.0 ? sampleZ0 : sampleZ1);

      float sampleWeight = clamp(abs(lz- linearSampleZ) * far / 16.0, 0.0, 1.0);
      sampleWeight = 1.0 - sampleWeight * sampleWeight;

      previousColoredLight += texture2D(colortex12, prevCoord.xy + offset).rgb * sampleWeight;
    }

    previousColoredLight *= 0.25;
    previousColoredLight *= previousColoredLight * mask;

    return sqrt(mix(previousColoredLight, lightAlbedo * lightAlbedo / 0.1, 0.1));
  }
#endif

#ifdef composite1
  vec3 getColoredBlockLight(vec3 blocklightCol, vec3 screenPos) {
    if (screenPos.z > 0.56) {
      screenPos.xy = reproject(screenPos);
    }
    vec3 coloredLight = texture2DLod(colortex12, screenPos.xy, 2).rgb;
    
    vec3 coloredLightNormalized = normalize(coloredLight + 0.00001);
    coloredLightNormalized *= getLuminance(blocklightCol) / getLuminance(coloredLightNormalized);
    float coloredLightMix = min((coloredLight.r + coloredLight.g + coloredLight.b) * 2048.0, 1.0);
    
    return mix(blocklightCol, coloredLightNormalized, coloredLightMix * 0.5);
  }
  vec3 blockLightOverrideColor;
#endif
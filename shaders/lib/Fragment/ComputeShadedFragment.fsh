#if !defined COMPUTESHADEDFRAGMENT_FSH
#define COMPUTESHADEDFRAGMENT_FSH

#include "/lib/Fragment/PrecomputedSky.glsl"

struct Shading { // Scalar light levels
	vec3 sunlight;
	float skylight;
	float caustics;
	float torchlight;
	float ambient;
};

struct Lightmap { // Vector light levels with color
	vec3 sunlight;
	vec3 skylight;
	vec3 torchlight;
	vec3 ambient;
	vec3 GI;
};


#include "/lib/Fragment/ComputeSunlight.fsh"


float GetHeldLight(vec3 viewSpacePosition, vec3 normal, float handMask) {
	float falloff;

	float light = max(heldBlockLightValue, heldBlockLightValue2);

	vec3 eyeOffset = eyePosition - cameraPosition; // offset of eye from camera, vec3(0.) in first person
	vec3 eyeOffsetView = mat3(gbufferModelView) * eyeOffset;

	vec3 lightPos = viewSpacePosition - eyeOffsetView; // position relative to player eye, ideally I would use hand position but idk where the hand is

	if (length(lightPos) < light){
		float dist = length(lightPos);
		falloff = light;
		falloff = clamp01(falloff);
		falloff = mix(falloff, 0, dist / light);
	}

	#ifdef DIRECTIONAL_LIGHTING
	falloff *= clamp01(dot(normal, -normalize(lightPos)));
	#endif

	return falloff;
}

#if defined composite1
#include "/lib/Fragment/ComputeWaveNormals.fsh"

float CalculateWaterCaustics(vec3 worldPos, float skyLightmap, float waterMask) {
#ifndef WATER_CAUSTICS
	return 1.0;
#endif
	
	if (skyLightmap <= 0.0 || WAVE_MULT == 0.0 || isEyeInWater == waterMask) return 1.0;
	
	SetupWaveFBM();
	
	worldPos += cameraPosition + gbufferModelViewInverse[3].xyz - vec3(0.0, 1.62, 0.0);
	
	float verticalDist = min(abs(worldPos.y - WATER_HEIGHT), 2.0);
	
	vec3 flatRefractVector  = refract(-worldLightVector, vec3(0.0, 1.0, 0.0), 1.0 / 1.3333);
	     flatRefractVector *= verticalDist / flatRefractVector.y;
	
	vec3 lookupCenter = worldPos + flatRefractVector;
	
	vec2 coord = lookupCenter.xz + lookupCenter.y;
	
	cfloat distanceThreshold = 0.15;
	
	float caustics = 0.0;
	
	vec3 r; // RIGHT height sample to rollover between columns
	vec3 a; // .x = center      .y = top      .z = right
	mat4x2[4] p;
	
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) { // 3x3 sample matrix. Starts bottom-left and immediately goes UP
			vec2 offset = vec2(x, y) * 0.1;
			
			// Generate heights for wave normal differentials. Lots of math & sample reuse happening
			if (x == -1 && y == -1) a.x = GetWaves(coord + offset, p[0]); // If bottom-left-position, generate the height & save FBM coords
			else if (x == -1)       a.x = a.y;                            // If left-column, reuse TOP sample from previous iteration
			else                    a.x = r[y + 1];                       // If not left-column, reuse RIGHT sample from previous column
			
			if (x != -1 && y != 1) a.y = r[y + 2]; // If not left-column and not top-row, reuse RIGHT sample from previous column 1 row up
			else a.y = GetWaves(p[x + 1], offset.y + 0.2); // If left-column or top-row, reuse previously computed FBM coords
			
			if (y == -1) a.z = GetWaves(coord + offset + vec2(0.1, 0.0), p[x + 2]); // If bottom-row, generate the height & save FBM coords
			else a.z = GetWaves(p[x + 2], offset.y + 0.2); // If not bottom-row, reuse FBM coords
			
			r[y + 1] = a.z; // Save RIGHT height sample for later
			
			
			vec2 diff = a.x - a.yz;
			
			vec3 wavesNormal = vec3(diff, sqrt(1.0 - length2(diff))).yzx;
			
			vec3 refractVector = refract(-worldLightVector, wavesNormal, 1.0 / 1.3333);
			vec2 dist = refractVector.xz * (-verticalDist / refractVector.y) + (flatRefractVector.xz + offset);
			
			caustics += clamp01(length(dist) / distanceThreshold);
		}
	}
	
	caustics = 1.0 - caustics / 9.0;
	caustics *= 0.07 / pow2(distanceThreshold);
	
	return pow3(caustics);
}
#else
#define CalculateWaterCaustics(a, c, b) 1.0
#endif

float Luma(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 ColorSaturate(vec3 base, float saturation) {
    return mix(base, vec3(Luma(base)), -saturation);
}

cvec3 nightColor = vec3(0.25, 0.35, 0.7);
#ifndef COLORED_BLOCKLIGHT
cvec3 torchColor = vec3(1.0, 0.46, 0.25) * 0.85;
#else
cvec3 torchColor = vec3(0.3, 0.22, 0.2) / 0.42;
#endif

vec3 LightDesaturation(vec3 color, float torchlight, float skylight, float emissive) {
//	if (emissive > 0.5) return vec3(color);
	
	vec3  desatColor = vec3(color.x + color.y + color.z);
	
	desatColor = mix(desatColor * nightColor, mix(desatColor, color, 0.5) * ColorSaturate(torchColor, 0.35) * 40.0, clamp01(torchlight * 2.0)*0+1);
	
	float moonFade = smoothstep(0.0, 0.3, max0(-worldLightVector.y));
	
	float coeff = clamp01(min(moonFade, 0.65) + pow(1.0 - skylight, 1.4));
	
	return mix(color, desatColor, coeff);
}

vec3 nightDesat(vec3 color, vec3 lightmap, cfloat mult, cfloat curve) {
	float desatAmount = clamp01(pow(length(lightmap) * mult, curve));
	vec3 desatColor = vec3(color.r + color.g + color.b);
	
	desatColor *= sqrt(desatColor);
	
	return mix(desatColor, color, desatAmount);
}

vec3 ComputeShadedFragment(vec3 diffuse, Mask mask, float torchLightmap, float skyLightmap, vec4 GI, vec3 normal, float emission, mat2x3 position, float materialAO, float SSS, vec3 geometryNormal, vec3 preCalculatedSunlight) {
	Shading shading;
	
#ifndef VARIABLE_WATER_HEIGHT
	if (mask.water != isEyeInWater) // Surface is in water
		skyLightmap = 1.0 - clamp01(-(position[1].y + cameraPosition.y - WATER_HEIGHT) / UNDERWATER_LIGHT_DEPTH);
#endif
	
	#ifdef world0
		shading.skylight = pow2(skyLightmap);
		
		shading.caustics = CalculateWaterCaustics(position[1], shading.skylight, mask.water);
		
		//shading.sunlight  = vec3(GetLambertianShading(normal, lightVector, mask) * shading.skylight);
		if(preCalculatedSunlight.r >= 0.0){
			shading.sunlight = preCalculatedSunlight;
		} else {
			shading.sunlight  = vec3(ComputeSunlight(position[1], normal, geometryNormal, 1.0, SSS));
		}
		//show(shading.sunlight);
		
		
		
		shading.skylight *= mix(shading.caustics * 0.65 + 0.35, 1.0, pow8(1.0 - abs(worldLightVector.y)));
		shading.skylight *= GI.a;
		shading.skylight *= 2.0 * SKY_LIGHT_LEVEL;
		#ifdef GI_ENABLED
			shading.skylight *= 0.9 * SKY_LIGHT_LEVEL;
		#endif
	#else
		shading.skylight = 0;
		shading.sunlight = vec3(0);
	#endif

	shading.torchlight  = torchLightmap;
	shading.torchlight = max(shading.torchlight, GetHeldLight(position[0], normal, mask.hand));

	clamp01(pow(shading.torchlight, 5.06) * (TORCH_LIGHT_LEVEL * 10));

	shading.torchlight *= GI.a;

	
	shading.ambient  = 0.5 + (1.0 - eyeBrightnessSmooth.g / 240.0) * 3.0;
	shading.ambient += nightVision * 50.0;
	shading.ambient *= GI.a * 0.5 + 0.5;
	shading.ambient *= 0.04 * AMBIENT_LIGHT_LEVEL;
	shading.ambient = mix(shading.ambient, shading.ambient / 2.0, materialAO);
	#ifdef worldm1 // nether - no sunlight or skylight so boost ambient
		shading.ambient *= 3;
		shading.ambient = clamp(shading.ambient, 0.2, 1.0);
		shading.torchlight *= 2;
	#endif
	#ifdef world1 // the end
		shading.ambient *= 3;
	#endif
	
	
	Lightmap lightmap;
	
	lightmap.sunlight = shading.sunlight * shading.caustics * sunlightColor;
	
	lightmap.skylight = shading.skylight * sqrt(skylightColor);
	
	lightmap.GI = GI.rgb * GI.a * sunlightColor;
	
	lightmap.ambient = vec3(shading.ambient) * vec3(1.0, 1.2, 1.4);
	
	

	#ifdef COLORED_BLOCKLIGHT
	// show(blockLightOverrideColor);
	lightmap.torchlight = shading.torchlight * blockLightOverrideColor;
	#else
	lightmap.torchlight = shading.torchlight * torchColor;
	#endif
	
	lightmap.skylight *= clamp01(1.0 - dot(lightmap.GI, vec3(1.0)) / 6.0);
	
	
//	lightmap.sunlight = GetSunAndSkyIrradiance(kPoint(position[1]), normal, sunVector, lightmap.skylight) * shading.sunlight*2.0;
	
	
	vec3 desatColor = vec3(pow(diffuse.r + diffuse.g + diffuse.b, 1.5));
	
#define LIGHT_DESATURATION
#ifndef LIGHT_DESATURATION
	desatColor = diffuse;
#endif
	
	vec3 composite =
	  diffuse * (lightmap.GI + lightmap.ambient + emission * 16)
	+ lightmap.sunlight   * mix(desatColor, diffuse, clamp01(pow(length(lightmap.sunlight  ) *  4.0, 0.1)))
	+ lightmap.skylight   * mix(desatColor, diffuse, clamp01(pow(length(lightmap.skylight  ) * 25.0, 0.2)))
	+ lightmap.torchlight * mix(desatColor, diffuse, clamp01(pow(length(lightmap.torchlight) *  1.0, 0.1)));


	return composite;
}

#endif

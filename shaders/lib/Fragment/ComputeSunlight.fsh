#if !defined COMPUTESUNLIGHT_FSH
#define COMPUTESUNLIGHT_FSH

#include "/lib/Misc/ShadowBias.glsl"

float GetLambertianShading(vec3 normal) {
	return clamp01(dot(normal, worldLightVector));
}

vec2 VogelDiscSample(int stepIndex, int stepCount, float rotation) {
    const float goldenAngle = 2.4;

    float r = sqrt(stepIndex + 0.5) / sqrt(float(stepCount));
    float theta = stepIndex * goldenAngle + rotation;

    return r * vec2(cos(theta), sin(theta));
}

// https://github.com/riccardoscalco/glsl-pcg-prng/blob/main/index.glsl
uint pcg(uint v) {
	uint state = v * uint(747796405) + uint(2891336453);
	uint word = ((state >> ((state >> uint(28)) + uint(4))) ^ state) * uint(277803737);
	return (word >> uint(22)) ^ word;
}

float prng (uint seed) {
	return float(pcg(seed)) / float(uint(0xffffffff));
}

float GetLambertianShading(vec3 normal, vec3 worldLightVector, Mask mask) {
	float shading = clamp01(dot(normal, worldLightVector));
	      shading = mix(shading, 1.0, mask.translucent);
	
	return shading;
}

// ask tech, idk
float ComputeSSS(float blockerDistance, float SSS, vec3 normal){
	#ifndef SUBSURFACE_SCATTERING
	return 0.0;
	#endif

	if(SSS < 0.0001){
		return 0.0;
	}

	float nDotL = dot(normal, lightVector);

	if(nDotL > -0.00001){
		return 0.0;
	}

	float s = 1.0 / (SSS * 0.06);
	float z = blockerDistance * 255;

	if(isnan(z)){
		z = 0.0;
	}

	float scatter = 0.25 * (exp(-s * z) + 3*exp(-s * z / 3));

	return clamp01(scatter);
}

vec3 SampleShadow(vec3 shadowClipPos){
	float biasCoeff;
	vec3 shadowScreenPos = BiasShadowProjection(shadowClipPos, biasCoeff) * 0.5 + 0.5;

		#if defined IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS && SHADOW_TYPE != 3
		float opaqueShadow = shadow2D(shadowtex1HW, shadowScreenPos).r;
		#else
		float opaqueShadow = step(shadowScreenPos.z, texture2D(shadowtex1, shadowScreenPos.xy).r);
		#endif

	if(opaqueShadow == 1.0){
		return vec3(1.0);
	}

	#if defined IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS && SHADOW_TYPE != 3
	float transparentShadow = shadow2D(shadowtex0HW, shadowScreenPos).r;
	#else
	float transparentShadow = step(shadowScreenPos.z, texture2D(shadowtex0, shadowScreenPos.xy).r);
	#endif

	vec4 shadowColorData = texture2D(shadowcolor0, shadowScreenPos.xy);
	vec3 shadowColor = shadowColorData.rgb * (1.0 - shadowColorData.a);

	return mix(shadowColor * opaqueShadow, vec3(1.0), transparentShadow);
}

float GetBlockerDistance(vec3 shadowClipPos){
	float biasCoeff;
	#if SHADOW_TYPE != 3
		vec3 shadowScreenPos = BiasShadowProjection(shadowClipPos, biasCoeff) * 0.5 + 0.5;
		float blockerDepth = texture2D(shadowtex0, shadowScreenPos.xy).r;
		return shadowScreenPos.z - blockerDepth;
	#endif

	float range = float(BLOCKER_SEARCH_RADIUS) / (2 * shadowDistance);

	vec3 receiverShadowScreenPos = BiasShadowProjection(shadowClipPos, biasCoeff) * 0.5 + 0.5;
	float receiverDepth = receiverShadowScreenPos.z;

	float blockerDistance = 0;

	float blockerCount = 0;

	for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++){
		vec2 offset = VogelDiscSample(i, BLOCKER_SEARCH_SAMPLES, ign(floor(gl_FragCoord.xy)));
		vec3 newShadowScreenPos = BiasShadowProjection(shadowClipPos + vec3(offset * range, 0.0), biasCoeff) * 0.5 + 0.5;
		float newBlockerDepth = texture2D(shadowtex0, newShadowScreenPos.xy).r;
		if (newBlockerDepth < receiverDepth){
			blockerDistance += (receiverDepth - newBlockerDepth);
			blockerCount += 1;
		}
	}

	if(blockerCount == 0){
		return 0.0;
	}
	blockerDistance /= blockerCount;

	return blockerDistance;
}

vec3 ComputeShadows(vec3 shadowClipPos, float penumbraWidthBlocks){
	if(penumbraWidthBlocks == 0.0){
		return(SampleShadow(shadowClipPos));
	}

	float penumbraWidth = penumbraWidthBlocks / shadowDistance;
	float range = penumbraWidth / 2;

	vec3 shadowSum = vec3(0.0);
	int samples = SHADOW_SAMPLES;

	#if defined IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS && SHADOW_TYPE == 2
	samples /= 4; // with hardware PCF we can take less samples
	#endif

	for(int i = 0; i < samples; i++){
		vec2 offset = VogelDiscSample(i, samples, ign(floor(gl_FragCoord.xy)));
		shadowSum += SampleShadow(shadowClipPos + vec3(offset * range, 0.0));
	}
	shadowSum /= float(samples);

	return shadowSum;
}

vec3 ComputeSunlight(vec3 worldSpacePosition, vec3 normal, vec3 geometryNormal, float sunlightCoeff, float SSS, float skyLightmap) {
	#ifndef WORLD_OVERWORLD
	return vec3(0.0);
	#endif

	float distCoeff = GetDistanceCoeff(worldSpacePosition);

	
	vec3 shadowClipPos = projMAD(shadowProjection, transMAD(shadowViewMatrix, worldSpacePosition + gbufferModelViewInverse[3].xyz));
	vec3 sunlight = vec3(1.0);

	float nDotL = clamp01(dot(mat3(gbufferModelViewInverse) * normal, worldLightVector));

	sunlight *= nDotL;

	float blockerDistance = GetBlockerDistance(shadowClipPos);

	#if SHADOW_TYPE == 0
	sunlight *= skyLightmap;
	#elif SHADOW_TYPE == 1
	float penumbraWidth = 0.0; // hard shadows
	#elif SHADOW_TYPE == 2
	float penumbraWidth = SHADOW_SOFTNESS * rcp(10); // soft shadows
	#elif SHADOW_TYPE == 3
	float penumbraWidth = mix(MIN_PENUMBRA_WIDTH, MAX_PENUMBRA_WIDTH, blockerDistance); // PCSS shadows
	#endif

	#if SHADOW_TYPE != 0
	sunlight *= ComputeShadows(shadowClipPos, penumbraWidth);
	sunlight = mix(sunlight, vec3(nDotL), distCoeff);
	
	float scatter = ComputeSSS(blockerDistance, SSS, geometryNormal);
	sunlight = max(sunlight, vec3(scatter));
	show(scatter);

	sunlight *= 1.0 * SUN_LIGHT_LEVEL;
	sunlight *= mix(1.0, 0.0, biomeWetness);
	#endif

	return sunlight;
}

#endif

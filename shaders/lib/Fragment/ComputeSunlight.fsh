#if !defined COMPUTESUNLIGHT_FSH
#define COMPUTESUNLIGHT_FSH

#include "/lib/Misc/ShadowBias.glsl"

float GetLambertianShading(vec3 normal) {
	return clamp01(dot(normal, worldLightVector));
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

mat2 getRandomRotation(vec2 offset){
	uint seed = uint(gl_FragCoord.x * viewHeight+ gl_FragCoord.y) * 720720u;
	seed += floatBitsToInt(
	gbufferModelViewInverse[2].x +
	gbufferModelViewInverse[2].y +
	gbufferModelViewInverse[2].z +
	cameraPosition.x +
	cameraPosition.y +
	cameraPosition.z
	);
	#ifdef DYNAMIC_NOISE
	seed += frameCounter;
	#endif
	float randomAngle = 2 * PI * prng(seed);
	float cosTheta = cos(randomAngle);
	float sinTheta = sin(randomAngle);
	return mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
}

// ask tech, idk
float calculateSSS(float blockerDepth, float receiverDepth, float SSS, vec3 normal){
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

	float s = 1.0 / (SSS * 0.12);
	float z = receiverDepth - blockerDepth;

	if(isnan(z)){
		z = 0.0;
	}

	float scatter = 0.25 * (exp(-s * z) + 3*exp(-s * z / 3));

	return clamp01(scatter);
}

vec3 SampleShadow(vec3 shadowClipPos){

	float biasCoeff;
	vec3 shadowScreenPos = BiasShadowProjection(shadowClipPos, biasCoeff) * 0.5 + 0.5;

	float transparentShadow = step(shadowScreenPos.z, texture2D(shadowtex0, shadowScreenPos.xy).r);
	float opaqueShadow = step(shadowScreenPos.z, texture2D(shadowtex1, shadowScreenPos.xy).r);
	vec4 shadowColor = texture2D(shadowtex0, shadowScreenPos.xy);

	return mix(shadowColor.rgb * opaqueShadow, vec3(1.0), transparentShadow);
}

vec3 ComputeShadows(vec3 shadowClipPos, float penumbraWidthBlocks){
	if(penumbraWidthBlocks == 0.0){
		return(SampleShadow(shadowClipPos));
	}

	float penumbraWidth = penumbraWidthBlocks / shadowDistance;
	

	float range = penumbraWidth / 2;
	float interval = penumbraWidth / float(SHADOW_SAMPLES);

	vec3 shadowSum = vec3(0.0);

	for (float y = -range; y <= range; y += interval){
		for (float x = -range; x <= range; x += interval){
			vec3 offset = vec3(x, y, 0.0);
			offset.xy = getRandomRotation(offset.xy) * offset.xy;

			shadowSum += SampleShadow(shadowClipPos + offset);
		}
	}

	shadowSum /= pow2(SHADOW_SAMPLES);

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

	sunlight *= ComputeShadows(shadowClipPos, SHADOW_SOFTNESS * rcp(10));
	sunlight = mix(sunlight, vec3(nDotL), distCoeff);

	sunlight *= 1.0 * SUN_LIGHT_LEVEL;
	sunlight *= mix(1.0, 0.0, biomeWetness);

	return sunlight;
}

#endif

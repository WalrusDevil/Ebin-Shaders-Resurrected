#if !defined COMPUTESUNLIGHT_FSH
#define COMPUTESUNLIGHT_FSH

#include "/lib/Misc/ShadowBias.glsl"

float GetLambertianShading(vec3 normal) {
	return clamp01(dot(normal, lightVector));
}

float GetLambertianShading(vec3 normal, vec3 lightVector, Mask mask) {
	float shading = clamp01(dot(normal, lightVector));
	      shading = mix(shading, 1.0, mask.translucent);
	
	return shading;
}

float shadowVisibility(sampler2D shadowMap, vec3 shadowPosition){
	return step(shadowPosition.z, texture2D(shadowMap, shadowPosition.xy).r);
}

mat2 getRandomRotation(vec2 offset){
	float randomAngle = texture2D(noisetex, (texcoord + offset) * 20.0f).r * 100.0f;
	float cosTheta = cos(randomAngle);
	float sinTheta = sin(randomAngle);
	return mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
}

#if SHADOW_TYPE == 2
	float ComputeShadows(vec3 shadowPosition, float biasCoeff) {
		float spread = (1.0 - biasCoeff) / shadowMapResolution;
		
		cfloat range       = SHADOW_SOFTNESS;
		cfloat interval    = 1.0 / range;
		cfloat sampleCount = pow(range / interval * 2.0 + 1.0, 2.0);
		
		float sunlight = 0.0;
		
		for (float y = -range; y <= range; y += interval){
			for (float x = -range; x <= range; x += interval){
				vec2 offset = vec2(x, y);
				offset = getRandomRotation(offset) * offset;
				#ifdef TRANSPARENT_SHADOWS
				float fullShadow = shadowVisibility(shadowtex0, shadowPosition + vec3(offset, 0) * spread);
				float opaqueShadow = shadowVisibility(shadowtex1, shadowPosition + vec3(offset, 0) * spread);
				float shadowTransparency = 1.0 - texture2D(shadowcolor0, shadowPosition.xy).a;

				sunlight += mix(shadowTransparency * opaqueShadow, 1.0, fullShadow);
				#else
				sunlight += shadowVisibility(shadowtex0, shadowPosition + vec3(offset, 0) * spread);
				#endif
			}
		}
		
		return sunlight / sampleCount;
	}
#else
	#define ComputeShadows(shadowPosition, biasCoeff) shadowVisibility(shadowtex0, shadowPosition);
#endif


float ComputeSunlight(vec3 worldSpacePosition, float sunlightCoeff) {
	if (sunlightCoeff <= 0.0) return sunlightCoeff;
	
	float distCoeff = GetDistanceCoeff(worldSpacePosition);
	
	if (distCoeff >= 1.0) return sunlightCoeff;
	
	float biasCoeff;
	
	vec3 shadowPosition = BiasShadowProjection(projMAD(shadowProjection, transMAD(shadowViewMatrix, worldSpacePosition + gbufferModelViewInverse[3].xyz)), biasCoeff) * 0.5 + 0.5;
	
	if (any(greaterThan(abs(shadowPosition.xyz - 0.5), vec3(0.5)))) return sunlightCoeff;
	
	float sunlight = ComputeShadows(shadowPosition, biasCoeff);
	      sunlight = mix(sunlight, 1.0, distCoeff);
	
	return sunlightCoeff * pow(sunlight, mix(2.0, 1.0, clamp01(length(worldSpacePosition) * 0.1)));
}

#endif

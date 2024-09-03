#if !defined COMPUTESUNLIGHT_FSH
#define COMPUTESUNLIGHT_FSH

#include "/lib/Misc/ShadowBias.glsl"
#include "/lib/Acid/portals.glsl"

vec4 noise;

float GetLambertianShading(vec3 normal) {
	return clamp01(dot(normal, worldLightVector));
}

vec2 VogelDiscSample(int stepIndex, int stepCount, float rotation) {
    const float goldenAngle = 2.4;

    float r = sqrt(stepIndex + 0.5) / sqrt(float(stepCount));
    float theta = stepIndex * goldenAngle + rotation;

    return r * vec2(cos(theta), sin(theta));
}

// ask tech, idk
float ComputeSSS(float nDotL, float SSS, vec3 normal){
	return mix(nDotL, pow2(nDotL * 0.5 + 0.5), SSS);
}

vec3 SampleShadow(vec3 shadowClipPos, bool useImageShadowMap){
	float biasCoeff;


	vec3 shadowScreenPos = BiasShadowProjection(shadowClipPos, biasCoeff) * 0.5 + 0.5;

	float shadow;
	if(useImageShadowMap){
		shadow = step(shadowScreenPos.z, texture(portalshadowtex, shadowScreenPos.xy).r);
	} else {
		shadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
	}

	return vec3(shadow);
}

vec3 ComputeShadows(vec3 shadowClipPos, float penumbraWidthBlocks, bool useImageShadowMap){
	#ifndef SHADOWS
	return vec3(1.0);
	#endif

	if(penumbraWidthBlocks == 0.0){
		return(SampleShadow(shadowClipPos, useImageShadowMap));
	}

	float penumbraWidth = penumbraWidthBlocks / shadowDistance;
	float range = penumbraWidth / 2;

	vec3 shadowSum = vec3(0.0);
	int samples = SHADOW_SAMPLES;


	for(int i = 0; i < samples; i++){
		vec2 offset = VogelDiscSample(i, samples, noise.g);
		shadowSum += SampleShadow(shadowClipPos + vec3(offset * range, 0.0), useImageShadowMap);
	}
	shadowSum /= float(samples);

	return shadowSum;
}

vec3 ComputeSunlight(vec3 worldSpacePosition, vec3 normal, vec3 geometryNormal, float sunlightCoeff, float SSS, float skyLightmap, bool rightOfPortal) {
	#ifndef WORLD_OVERWORLD
	return vec3(0.0);
	#endif

	float distCoeff = GetDistanceCoeff(worldSpacePosition);

	
	vec3 shadowClipPos = projMAD(shadowProjection, transMAD(shadowViewMatrix, worldSpacePosition + gbufferModelViewInverse[3].xyz));
	vec3 sunlight = vec3(1.0);

	float nearestPortalX = getNearestPortalX(cameraPosition.x);

	bool useImageShadowMap = (
		((cameraPosition.x < nearestPortalX && rightOfPortal) ||
		(cameraPosition.x > nearestPortalX && !rightOfPortal)) &&
		abs((worldSpacePosition.x + cameraPosition.x) - nearestPortalX) < PORTAL_RENDER_DISTANCE * 16 / 2
	);

	noise = vec4(InterleavedGradientNoise(floor(gl_FragCoord.xy)));

	float nDotL = clamp01(dot(normal, lightVector));

	float penumbraWidth = SHADOW_SOFTNESS * rcp(10); // soft shadows

	vec3 shadow = ComputeShadows(shadowClipPos, penumbraWidth, useImageShadowMap);
	float scatter = ComputeSSS(nDotL, SSS, geometryNormal);
	sunlight = shadow * scatter;
	sunlight = mix(sunlight, vec3(nDotL), distCoeff);



	sunlight *= 1.0 * SUN_LIGHT_LEVEL;
	sunlight *= mix(1.0, 0.0, biomePrecipness);



	return sunlight;
}

#endif

#if !defined COMPUTESUNLIGHT_FSH
#define COMPUTESUNLIGHT_FSH

#include "/lib/Misc/ShadowBias.glsl"

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

vec3 SampleShadow(vec3 shadowClipPos){
	float biasCoeff;
	vec3 shadowScreenPos = BiasShadowProjection(shadowClipPos, biasCoeff) * 0.5 + 0.5;

	#if defined IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
	float transparentShadow = shadow2D(shadowtex0HW, shadowScreenPos).r;
	#else
	float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
	#endif

	return vec3(transparentShadow);
}

vec3 ComputeShadows(vec3 shadowClipPos, float penumbraWidthBlocks){
	if(penumbraWidthBlocks == 0.0){
		return(SampleShadow(shadowClipPos));
	}

	float penumbraWidth = penumbraWidthBlocks / shadowDistance;
	float range = penumbraWidth / 2;

	vec3 shadowSum = vec3(0.0);
	int samples = SHADOW_SAMPLES;


	for(int i = 0; i < samples; i++){
		vec2 offset = VogelDiscSample(i, samples, noise.g);
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



	noise = vec4(InterleavedGradientNoise(floor(gl_FragCoord.xy)));

	float nDotL = clamp01(dot(normal, lightVector));

	float penumbraWidth = SHADOW_SOFTNESS * rcp(10); // soft shadows

	vec3 shadow = ComputeShadows(shadowClipPos, penumbraWidth);
	float scatter = ComputeSSS(nDotL, SSS, geometryNormal);
	sunlight = shadow * scatter;
	sunlight = mix(sunlight, vec3(nDotL), distCoeff);



	sunlight *= 1.0 * SUN_LIGHT_LEVEL;
	sunlight *= mix(1.0, 0.0, biomePrecipness);



	return sunlight;
}

#endif

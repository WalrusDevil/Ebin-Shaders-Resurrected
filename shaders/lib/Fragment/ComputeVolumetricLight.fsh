#if !defined COMPUTEVOLUMETRICLIGHT_FSH
#define COMPUTEVOLUMETRICLIGHT_FSH

#include "/lib/Fragment/3D_Clouds.fsh"

vec2 ComputeVolumetricLight(vec3 position, vec3 frontPos, vec2 noise, float waterMask) {
#ifndef VL_ENABLED
	return vec2(0.0);
#endif
	
	vec3 ray = normalize(position); // this is in world space
	vec3 worldRay = ray;

	ray = projMAD(shadowProjection, transMAD(shadowViewMatrix, ray + gbufferModelViewInverse[3].xyz)); // transforms ray into shadow space
	
	vec3 shadowStep = diagonal3(shadowProjection) * (mat3(shadowViewMatrix) * ray); // the direction the ray steps in in shadow space
	vec3 worldStep = worldRay;
	
	
	
#ifdef LIMIT_SHADOW_DISTANCE
	cfloat maxSteps = min(200.0, shadowDistance);
#else
	cfloat maxSteps = 200.0;
#endif

	#if defined CLOUD3D && defined CLOUD_VOLUMETRICS
		CloudFBM1(CLOUD3D_SPEED);
		float coverage = CLOUD3D_COVERAGE + biomeWetness * 0.335;
		#ifdef BIOME_WEATHER
		coverage += -0.2 + (0.15 * humiditySmooth);
		#endif
		float sunglow = 0.0;
	#endif

	
	float end    = min(length(position), maxSteps);
	float count  = 1.0;
	vec2  result = vec2(0.0);

	shadowStep *= rcp(VL_QUALITY);
	end *= VL_QUALITY;
	
	float frontLength = length(frontPos);
	
	while (count < end) {
		vec3 samplePos = BiasShadowProjection(ray) * 0.5 + 0.5;
		vec3 worldSamplePos = worldRay * 0.5 + 0.5;
		
		#ifdef WATER_CAUSTICS
			float fullShadow = step(samplePos.z, texture2D(shadowtex0, samplePos.xy).r);
			float opaqueShadow = step(samplePos.z, texture2D(shadowtex1, samplePos.xy).r);
			vec4 shadowData = texture2D(shadowcolor0, samplePos.xy);
			vec3 shadowColor = shadowData.xyz * (1.0 - shadowData.a);
			float shadow = length(mix(shadowColor * opaqueShadow, vec3(1.0), fullShadow));
		#else
			float shadow = step(samplePos.z, texture2D(shadowtex1, samplePos.xy).r);
		#endif

		#if defined CLOUD3D && defined CLOUD_VOLUMETRICS
		if(shadow != 1.0){
			vec4 cloud;
			RaymarchClouds(cloud, mat3(gbufferModelViewInverse) * sunPosition, worldRay, sunglow, 3, CLOUD3D_NOISE, CLOUD3D_DENSITY, coverage, CLOUD3D_START_HEIGHT, CLOUD3D_DEPTH);
			shadow *= cloud.a;
		}
		#endif
		
		result += shadow * vec2(1.0, 0.0);
		
		count++;
		ray += shadowStep;
		worldRay += worldStep;
	}
	
	// result = isEyeInWater == 0 ? result.xy : result.yx;
	
	result /= end;



	return result;
}

#endif

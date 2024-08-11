#if !defined COMPUTEVOLUMETRICLIGHT_FSH
#define COMPUTEVOLUMETRICLIGHT_FSH

vec2 ComputeVolumetricLight(vec3 position, vec3 frontPos, vec2 noise, float waterMask) {
#ifndef VL_ENABLED
	return vec2(0.0);
#endif

#ifndef WORLD_OVERWORLD
	return vec2(0.0);
#endif
	
	vec3 ray = normalize(position);
	
	vec3 shadowStep = diagonal3(shadowProjection) * (mat3(shadowViewMatrix) * ray);
	
	ray = projMAD(shadowProjection, transMAD(shadowViewMatrix, ray + gbufferModelViewInverse[3].xyz));
	
#ifdef LIMIT_SHADOW_DISTANCE
	cfloat maxSteps = min(200.0, shadowDistance);
#else
	cfloat maxSteps = 200.0;
#endif
	
	float end    = min(length(position), maxSteps);
	float count  = 1.0;
	vec2  result = vec2(0.0);

	shadowStep *= rcp(VL_QUALITY);
	end *= VL_QUALITY;
	
	float frontLength = length(frontPos);
	
	while (count < end) {
		vec3 samplePos = BiasShadowProjection(ray) * 0.5 + 0.5;
		
		#ifdef WATER_CAUSTICS
		float shadow;

		#ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
		float opaqueShadow = shadow2D(shadowtex0HW, samplePos).r;
		#else
		float opaqueShadow = step(samplePos.z, texture2D(shadowtex0, samplePos.xy).r);
		#endif


		if(opaqueShadow == 1.0){
			shadow = 1.0;
		} else {

			#ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
			float fullShadow = shadow2D(shadowtex1HW, samplePos).r;
			#else
			float fullShadow = step(samplePos.z, texture2D(shadowtex1, samplePos.xy).r);
			#endif


			vec4 shadowData = texture2D(shadowcolor0, samplePos.xy);
			vec3 shadowColor = shadowData.xyz * (1.0 - shadowData.a);
			shadow = length(mix(shadowColor * opaqueShadow, vec3(1.0), fullShadow));
		}
		
		#else
		float shadow = step(samplePos.z, texture2D(shadowtex1, samplePos.xy).r);
		#endif
		
		result += shadow * vec2(1.0, 0.0);
		count++;
		ray += shadowStep;
	}
	
	// result = isEyeInWater == 0 ? result.xy : result.yx;
	
	return result / end;
}

#endif

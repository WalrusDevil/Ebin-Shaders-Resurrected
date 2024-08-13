#if !defined COMPUTEVOLUMETRICLIGHT_FSH
#define COMPUTEVOLUMETRICLIGHT_FSH

vec2 ComputeVolumetricLight(vec3 position, vec3 frontPos, vec2 noise, float waterMask) {
#ifndef VL_ENABLED
	return vec2(0.0);
#endif

#ifndef WORLD_OVERWORLD
	return vec2(0.0);
#endif
	
	cfloat samples = VL_QUALITY	;
	vec3 ray = normalize(position);
	
	vec3 shadowStep = diagonal3(shadowProjection) * (mat3(shadowViewMatrix) * ray);
	
	ray = projMAD(shadowProjection, transMAD(shadowViewMatrix, ray + gbufferModelViewInverse[3].xyz));

	vec2 result = vec2(0.0);
	
#ifdef LIMIT_SHADOW_DISTANCE
	float maxDistance = min(length(position), shadowDistance);
#else
	float maxDistance = length(position);
#endif

	maxDistance = min(maxDistance, 128);
	
	float frontLength = length(frontPos);
	
	for(int i = 0; i < samples; i++) {

		float noise = ign(floor(gl_FragCoord.xy), i);

		vec3 samplePos = BiasShadowProjection(ray + shadowStep * noise * maxDistance) * 0.5 + 0.5;
		
		#ifdef WATER_CAUSTICS
			float shadow;
			#if defined IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
			float transparentShadow = shadow2D(shadowtex0HW, samplePos).r;
			#else
			float transparentShadow = step(samplePos.z, texture2D(shadowtex0, samplePos.xy).r);
			#endif

			if(transparentShadow == 1.0){ // no shadow at all
				shadow = 1.0;
			} else {
				#if defined IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
				float opaqueShadow = shadow2D(shadowtex1HW, samplePos).r;
				#else
				float opaqueShadow = step(samplePos.z, texture2D(shadowtex1, samplePos.xy).r);
				#endif

				if(opaqueShadow == 0.0){ // only opaque shadow so don't sample opaque shadow map
					shadow = 0.0;
				} else {
					vec4 shadowColorData = texture2D(shadowcolor0, samplePos.xy);
					shadow = shadowColorData.a;
				}
			}

			
			
		#else
			float shadow = step(samplePos.z, texture2D(shadowtex1, samplePos.xy).r);
		#endif
		
		result += shadow * vec2(1.0, 0.0);
	}
	
	// result = isEyeInWater == 0 ? result.xy : result.yx;
	
	return result / samples;
}

#endif

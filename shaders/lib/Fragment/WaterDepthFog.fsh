#if !defined waterdepthFOG_FSH
#define waterdepthFOG_FSH

cvec3 waterColor = vec3(0.015, 0.04, 0.098);

vec3 waterdepthFog(vec3 frontPos, vec3 backPos, vec3 color) {
#ifdef CLEAR_WATER
	return color;
#endif
	
	float waterdepth = distance(backPos.xyz, frontPos.xyz); // Depth of the water volume
	
	if (isEyeInWater != 0.0) waterdepth = length(frontPos) * 0.5;
	
	// Beer's Law
	float fogAccum = exp(-waterdepth * 0.05);
	vec3 tint = (sunlightColor * sqrt(skyLightmap)) * 0.9 + 0.1;
	tint = sqrt(tint * length(tint));

	if(isEyeInWater != 1.0){
		tint = vec3(0.0);
	}

	color *= pow(vec3(0.6, 0.7, 0.8), vec3(waterdepth));
	color = mix(color, waterColor * tint, 1.0 - clamp01(fogAccum));
	return color;
}

#endif

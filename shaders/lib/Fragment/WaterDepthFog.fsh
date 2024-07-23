#if !defined waterdepthFOG_FSH
#define waterdepthFOG_FSH

cvec3 waterColor = vec3(0.015, 0.04, 0.098);

vec3 waterdepthFog(vec3 frontPos, vec3 backPos, vec3 color) {
#ifdef CLEAR_WATER
	return color;
#endif
	
	float waterdepth = distance(backPos.xyz, frontPos.xyz) * 0.5; // Depth of the water volume
	
	if (isEyeInWater != 0.0) waterdepth = length(frontPos);
	
	// Beer's Law
	float fogAccum = exp(-waterdepth * 0.05);
	
	vec3 waterdepthColors = waterColor * sunlightColor;
	
	color *= pow(vec3(0.1, 0.5, 0.8), vec3(waterdepth));
	color  = mix(waterdepthColors, color, clamp01(fogAccum));

	return color;
}

#endif

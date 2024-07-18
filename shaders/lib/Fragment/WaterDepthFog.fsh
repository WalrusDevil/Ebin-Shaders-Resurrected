#if !defined WATERDEPTHFOG_FSH
#define WATERDEPTHFOG_FSH

cvec3 waterColor = vec3(0.015, 0.04, 0.098);

vec3 WaterDepthFog(vec3 frontPos, vec3 backPos, vec3 color) {
#ifdef CLEAR_WATER
	return color;
#endif
	
	float waterDepth = distance(backPos.xyz, frontPos.xyz) * 0.5; // Depth of the water volume
	
	if (isEyeInWater == 1) waterDepth = length(frontPos);
	
	// Beer's Law
	float fogAccum = exp(-waterDepth * 0.05);
	
	vec3 waterDepthColors = waterColor;
	
	color *= mix(vec3(1.0), pow(vec3(0.1, 0.5, 0.8), vec3(waterDepth)), 0.3);  // TODO, additional fog based on depth below sea level
	color  = mix(waterDepthColors, color, clamp01(fogAccum));

	return color;
}

#endif

#if !defined CALCULATEFOGFACTOR_GLSL
#define CALCULATEFOGFACTOR_GLSL


#define FOG_POWER 3.0 // [1.0 1.5 2.0 3.0 4.0 6.0 8.0]
#define FOG_START 0.2 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8]

float CalculateFogFactor(vec3 position) {
#ifndef FOG_ENABLED
	return 0.0;
#endif

#ifdef WORLD_THE_END //end
	return 0.0;
#endif
	
	float fogfactor  = length(position) / far;
		  fogfactor  = clamp01(fogfactor - FOG_START) / (1.0 - FOG_START);
		  fogfactor  = pow(fogfactor, FOG_POWER);
		  fogfactor  = clamp01(fogfactor);
	
	return fogfactor;
}

#endif

#if !defined COMPUTESSREFLECTIONS_FSH
#define COMPUTESSREFLECTIONS_FSH

int GetMaxSteps(vec3 pos, vec3 ray, float maxRayDepth, float rayGrowth) { // Returns the number of steps until the ray goes offscreen, or past maxRayDepth
	vec4 c =  vec4(diagonal2(projMatrix) * pos.xy + projMatrix[3].xy, diagonal2(projMatrix) * ray.xy);
	     c = -vec4((c.xy - pos.z) / (c.zw - ray.z), (c.xy + pos.z) / (c.zw + ray.z)); // Solve for (M*(pos + ray*c) + A) / (pos.z + ray.z*c) = +-1.0
	
	c = mix(c, vec4(1000000.0), lessThan(c, vec4(0.0))); // Remove negative coefficients from consideration by making them B I G
	
	float x = minVec4(c); // Nearest ray length to reach screen edge
	
	if (ray.z < 0.0) // If stepping away from player
		x = min(x, (maxRayDepth + pos.z) / -ray.z); // Clip against maxRayDepth
	
	x = (log2(1.0 - x*(1.0 - rayGrowth))) / log2(rayGrowth); // Solve geometric sequence with  a = 1.0  and  r = rayGrowth
	
	return min(75, int(x));
}



vec3 randomVector(int sampleCount){
	uint seed = uint(gl_FragCoord.x * viewHeight+ gl_FragCoord.y);
  seed = seed * 720720u + uint(sampleCount);
	seed += floatBitsToInt(
	gbufferModelViewInverse[2].x +
	gbufferModelViewInverse[2].y +
	gbufferModelViewInverse[2].z +
	cameraPosition.x +
	cameraPosition.y +
	cameraPosition.z
	);

	#ifdef DYNAMIC_NOISE
	seed += frameCounter;
	#endif

	float theta = acos(sqrt(prng(seed)));
	float phi = 2 * PI * prng(seed+seed);
	return vec3(sin(phi)*cos(theta), sin(phi)*sin(theta), cos(phi));
}

bool ComputeSSRaytrace(vec3 vPos, vec3 dir, out vec3 screenPos) {
	cfloat rayGrowth      = 1.15;
	cfloat rayGrowthL2    = log2(rayGrowth);
	cint   maxRefinements = 0;
	cbool  doRefinements  = maxRefinements != 0;
	float  maxRayDepth    = far * 1.75;
	int    maxSteps       = GetMaxSteps(vPos, dir, maxRayDepth, rayGrowth);
	
	vec3 rayStep = dir;
	vec3 ray = vPos + rayStep;
	
	float refinements = 0.0;
	
	vec2 zMAD = -vec2(projInverseMatrix[2][3] * 2.0, projInverseMatrix[3][3] - projInverseMatrix[2][3]);
	
	for (int i = 0; i < maxSteps; i++) {
		screenPos.st = ViewSpaceToScreenSpace(ray);
		
	//	if (any(greaterThan(abs(screenPos.st - 0.5), vec2(0.5))) || -ray.z > maxRayDepth) return false;
		
		screenPos.z = texture2D(depthtex1, screenPos.st).x;
		
		if (screenPos.z < 0.56){ // don't show hand in reflections
			return false;
		}

		float depth = screenPos.z * zMAD.x + zMAD.y;
		
		if (ray.z * depth >= 1.0) { // if (1.0 / (depth * a + b) >= ray.z), quick way to compare ray with hyperbolic sample depth without doing a division
			float diff = (1.0 / depth) - ray.z;
			
			if (doRefinements) {
				float error = exp2(i * rayGrowthL2 + refinements); // length(rayStep) * exp2(refinements)
				
				if (refinements <= maxRefinements && diff <= error * 2.0) {
					rayStep *= 0.5;
					ray -= rayStep;
					refinements++;
					continue;
				} else if (refinements > maxRefinements && diff <= error * 4.0) {
					return true;
				}
			} else return (diff <= exp2(i * rayGrowthL2 + 1.0));
		}
		
		ray += rayStep;
		
		rayStep *= rayGrowth;
	}
	
	return false;
}

vec3 getMetalf0(float baseReflectance, vec3 color){
	switch(int(baseReflectance * 255)){
			case 230: // Iron
					return vec3(0.24867, 0.22965, 0.21366);
			case 231: // Gold
					return vec3(0.88140, 0.57256, 0.11450);
			case 232: // Aluminum
					return vec3(0.81715, 0.82021, 0.83177);
			case 233: // Chrome
					return vec3(0.27446, 0.27330, 0.27357);
			case 234: // Copper
					return vec3(0.84430, 0.48677, 0.22164);
			case 235: // Lead
					return vec3(0.36501, 0.35675, 0.37653);
			case 236: // Platinum
					return vec3(0.42648, 0.37772, 0.31138);
			case 237: // Silver
					return vec3(0.91830, 0.89219, 0.83662);
	}
	return clamp01(color);
}

void ComputeSSReflections(io vec3 color, mat2x3 position, vec3 normal, float baseReflectance, float perceptualSmoothness, float skyLightmap) {
	if (baseReflectance == 0) return;

	float roughness = pow(1.0 - perceptualSmoothness, 2.0);
	

	//if (isEyeInWater == 1) return;

	float nDotV;

	vec3 v = normalize(-position[0]);
	vec3 n = normal;
	if (roughness > 0){
		vec3 roughN = normalize(v + n);
		nDotV = clamp01(dot(roughN, v));
	} else {
		nDotV = dot(n, v);
	}
	

	//float nDotV = clamp01(dotNorm(-position[0], normal));

	vec3 fresnel;

	if (baseReflectance < (229.0 / 255.0)) {
		fresnel = vec3(baseReflectance + (1 - (baseReflectance)) * pow(1 - nDotV, 5)); // schlick approximation
	} else {
		vec3 metalReflectance = getMetalf0(baseReflectance, color);
		fresnel = metalReflectance + (1 - (metalReflectance)) * pow(1 - nDotV, 5); // schlick approximation
	}
  
	
	if (length(fresnel) < 0.0005) return;
	

	mat2x3 refRay;
	
	vec3 refCoord;
	
	
	float fogFactor = 1.0;
	
	vec3 reflectionSum = vec3(0);
	vec3 offsetNormal = normal;

	for(int i = 0; i < REFLECTION_SAMPLES; i++){
		
		if (roughness > 0){ // rough reflections
			vec3 randomNormal = randomVector(i);
			if (dot(randomNormal, normal) < 0){ // new random normal faces into surface
				randomNormal *= -1;
			}

			offsetNormal = mix(normal, randomNormal, roughness);
		}

		refRay[0] = reflect(position[0], offsetNormal);
		refRay[1] = mat3(gbufferModelViewInverse) * refRay[0];

		vec3 reflection = vec3(0);
		bool hit = ComputeSSRaytrace(position[0], normalize(refRay[0]), refCoord);
	
		vec3 transmit = vec3(1.0);
		vec3 in_scatter = vec3(0.0);
		
		if (hit) {
			reflection = GetColor(refCoord.st);
			
			vec3 refVPos = CalculateViewSpacePosition(refCoord);
			
			fogFactor = length(abs(position[0] - refVPos) / 500.0);
			
			float angleCoeff = clamp01(pow(offsetNormal.z + 0.15, 0.25) * 2.0) * 0.2 + 0.8;
			float dist       = length8(abs(refCoord.st - vec2(0.5)));
			float edge       = clamp01(1.0 - pow2(dist * 2.0 * angleCoeff));
			fogFactor        = clamp01(fogFactor + pow(1.0 - edge, 10.0));
			
			#ifndef world2
			in_scatter = SkyAtmosphereToPoint(position[1], mat3(gbufferModelViewInverse) * refVPos, transmit);
			#endif
		} else {
			#ifndef world2
			in_scatter = ComputeSky(normalize(refRay[1]), position[1], transmit, 1.0, true) * skyLightmap;
			transmit = vec3(1.0);

			in_scatter *= skyLightmap * (1.0 - isEyeInWater);
			#else
			reflection = mix(color, vec3(0.02, 0.02, 0), 0.5);
			#endif
		}
		
		reflection = reflection * transmit + in_scatter;
		reflectionSum += reflection;

		

		if (roughness == 0){
			break;
		}
	}

	
	
	if (roughness > 0){
		reflectionSum /= REFLECTION_SAMPLES;
	}

	#ifdef MULTIPLY_METAL_ALBEDO
		if (baseReflectance >= (229.0 / 255.0)) {
			reflectionSum *= color;
		}
	#endif
	
	if (baseReflectance < 1.0){
		color = mix(color, reflectionSum, clamp01(fresnel));
		
	}
	
}


#endif

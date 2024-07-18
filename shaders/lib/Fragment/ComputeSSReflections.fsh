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
	int seed = floatBitsToInt(
	gbufferModelViewInverse[2].x +
	gbufferModelViewInverse[2].y +
	gbufferModelViewInverse[2].z +
	cameraPosition.x +
	cameraPosition.y +
	cameraPosition.z
	) + sampleCount;

	float theta = acos(ign(floor(texcoord * vec2(viewWidth, viewHeight)), seed));
	float phi = 2 * PI * ign(texcoord * vec2(viewWidth, viewHeight) + vec2(97, 23), seed);
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
					return vec3(0.78, 0.77, 0.74);
			case 231: // Gold
					return vec3(1.00, 0.90, 0.61);
			case 232: // Aluminum
					return vec3(1.00, 0.98, 1.00);
			case 233: // Chrome
					return vec3(0.77, 0.80, 0.79);
			case 234: // Copper
					return vec3(1.00, 0.89, 0.73);
			case 235: // Lead
					return vec3(0.79, 0.87, 0.85);
			case 236: // Platinum
					return vec3(0.92, 0.90, 0.83);
			case 237: // Silver
					return vec3(1.00, 1.00, 0.91);
	}
	return clamp01(color);
}

vec3 getMetalf82(float baseReflectance, vec3 color){
	switch(int(baseReflectance * 255)){
			case 230: // Iron
					return vec3(0.74, 0.76, 0.76);
			case 231: // Gold
					return vec3(1.00, 0.93, 0.73);
			case 232: // Aluminum
					return vec3(0.96, 0.97, 0.98);
			case 233: // Chrome
					return vec3(0.74, 0.79, 0.78);
			case 234: // Copper
					return vec3(1.00, 0.90, 0.80);
			case 235: // Lead
					return vec3(0.83, 0.80, 0.83);
			case 236: // Platinum
					return vec3(0.89, 0.87, 0.81);
			case 237: // Silver
					return vec3(1.00, 1.00, 0.95);
	}
	return clamp01(color);
}

// https://advances.realtimerendering.com/s2017/DecimaSiggraph2017.pdf
float getNoHSquared(float NoL, float NoV, float VoL) {
    float radiusCos = 1.0 - SUN_ANGULAR_PERCENTAGE;
		float radiusTan = tan(acos(radiusCos));
    
    float RoL = 2.0 * NoL * NoV - VoL;
    if (RoL >= radiusCos)
        return 1.0;

    float rOverLengthT = radiusCos * radiusTan / sqrt(1.0 - RoL * RoL);
    float NoTr = rOverLengthT * (NoV - RoL * NoL);
    float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);

    float triple = sqrt(clamp(1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL, 0.0, 1.0));
    
    float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
    float NoLVTr = NoL * radiusCos + NoV + NoTr, VoLVTr = VoL * radiusCos + 1.0 + VoTr;
    float p = NoBr * VoLVTr, q = NoLVTr * VoLVTr, s = VoBr * NoLVTr;    
    float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
    float xDenom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr + 
                   q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
    float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
    float sinTheta = twoX1 * xDenom;
    float cosTheta = 1.0 - twoX1 * xNum;
    NoTr = cosTheta * NoTr + sinTheta * NoBr;
    VoTr = cosTheta * VoTr + sinTheta * VoBr;
    
    float newNoL = NoL * radiusCos + NoTr;
    float newVoL = VoL * radiusCos + VoTr;
    float NoH = NoV + newNoL;
    float HoH = 2.0 * newVoL + 2.0;
    return clamp(NoH * NoH / HoH, 0.0, 1.0);
}

float ggx (vec3 N, vec3 V, vec3 L, float roughness) { // trowbridge-reitz
  float alpha = roughness*roughness;

  vec3 H = normalize(L + V);
	// float dotNHSquared = pow2(dot(N, H));
	float dotNHSquared = getNoHSquared(dot(N, L), dot(N, V), dot(V, L));
	float distr = dotNHSquared * (alpha - 1.0) + 1.0;
	return alpha / (PI * pow2(distr));
}

void ComputeSSReflections(io vec3 color, mat2x3 position, vec3 normal, float baseReflectance, float perceptualSmoothness, float skyLightmap) {
	if (baseReflectance == 0) return;

	float roughness = pow(1.0 - perceptualSmoothness, 2.0);

	float nDotV;

	vec3 v = normalize(-position[0]);
	vec3 n = normal;
	if (roughness > 0){
		vec3 roughN = normalize(v + n);
		nDotV = clamp01(dot(roughN, v));
	} else {
		nDotV = dot(n, v);
	}

	float specularHighlight = ggx(n, v, lightVector, max(roughness, 0.02));
	

	vec3 fresnel;

	if (baseReflectance < (229.0 / 255.0)) {
		fresnel = vec3(baseReflectance + (1 - (baseReflectance)) * pow(1 - nDotV, 5)); // schlick approximation
	} else {
		vec3 f0 = getMetalf0(baseReflectance, color); // lazanyi 2019 schlick
		vec3 f82 = getMetalf82(baseReflectance, color);
		vec3 a = 17.6513846 * (f0 - f82) + 8.16666667 * (1.0 - f0);
		float m = pow(1 - nDotV, 5);
		fresnel = clamp01(f0 + (1.0 - f0) * m - a * nDotV * (m - m * nDotV));
	}
  
	
	if (length(fresnel) < 0.0005) return;

	mat2x3 refRay;
	
	vec3 refCoord;
	
	
	float fogFactor = 1.0;
	
	vec3 reflectionSum = vec3(0);
	vec3 offsetNormal = normal;

	refRay[0] = reflect(position[0], offsetNormal);
	refRay[1] = mat3(gbufferModelViewInverse) * refRay[0];
	
	vec3 sunlight;

	if(abs(depth0 - depth1) < 0.0001){
		sunlight = texture(colortex10, texcoord).rgb;
	} else {
		sunlight = texture(colortex13, texcoord).rgb;
	}
	
	for(int i = 0; i < REFLECTION_SAMPLES; i++){
		
		if(roughness > ROUGH_REFLECTION_THRESHOLD){
			break;
		}

		if (roughness > 0){ // rough reflections
			vec3 randomNormal = randomVector(i);
			if (dot(randomNormal, normal) < 0){ // new random normal faces into surface
				randomNormal *= -1;
			}

			offsetNormal = slerp(normal, randomNormal, roughness);
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
			
			#ifndef worldm1
			in_scatter = SkyAtmosphereToPoint(position[1], mat3(gbufferModelViewInverse) * refVPos, transmit);
			#endif
		} else {
			
			#ifndef worldm1
			transmit = vec3(1.0);

			float sunFactor = 0.0;
			// if(roughness == 0.0){
			// 	sunFactor = 1.0 * 20; // I hate this
			// }

			in_scatter = ComputeSky(normalize(refRay[1]), position[1], transmit, 1.0, true, sunFactor) * skyLightmap;
			
			
	
			//length(ComputeSunlight(position[1], GetLambertianShading(normal) * skyLightmap));

			in_scatter *= (1.0 - isEyeInWater);
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

	

	vec3 transmit = vec3(1.0);
	vec3 sunspot = sunlightColor * specularHighlight * sunlight;

	if(roughness > ROUGH_REFLECTION_THRESHOLD){
		reflectionSum = color;
	}

	reflectionSum += sunspot;

	show(sunspot);
	


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

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
		if(screenPos.z < 0.56){
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
	switch(int(baseReflectance * 255 + 0.5)){
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
	switch(int(baseReflectance * 255 + 0.5)){
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

mat3 CalculateTBN(vec3 normal){
	vec3 tangent = normal.y == 1.0 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), normal));
	vec3 bitangent = normalize(cross(tangent, normal));
	return mat3(tangent, bitangent, normal);
}

// by Zombye
// https://discordapp.com/channels/237199950235041794/525510804494221312/1118170604160421918
vec3 SampleVNDFGGX(
    vec3 viewerDirection, // Direction pointing towards the viewer, oriented such that +Z corresponds to the surface normal
    vec2 alpha, // Roughness parameter along X and Y of the distribution
    vec2 xy // Pair of uniformly distributed numbers in [0, 1)
) {
    // Transform viewer direction to the hemisphere configuration
    viewerDirection = normalize(vec3(alpha * viewerDirection.xy, viewerDirection.z));

    // Sample a reflection direction off the hemisphere
    const float tau = 6.2831853; // 2 * pi
    float phi = tau * xy.x;
    float cosTheta = fma(1.0 - xy.y, 1.0 + viewerDirection.z, -viewerDirection.z);
    float sinTheta = sqrt(clamp(1.0 - cosTheta * cosTheta, 0.0, 1.0));
    vec3 reflected = vec3(vec2(cos(phi), sin(phi)) * sinTheta, cosTheta);

    // Evaluate halfway direction
    // This gives the normal on the hemisphere
    vec3 halfway = reflected + viewerDirection;

    // Transform the halfway direction back to hemiellispoid configuation
    // This gives the final sampled normal
    return normalize(vec3(alpha * halfway.xy, halfway.z));
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
  float alpha = roughness;

  vec3 H = normalize(L + V);
	// float dotNHSquared = pow2(dot(N, H));
	float dotNHSquared = getNoHSquared(dot(N, L), dot(N, V), dot(V, L));
	float distr = dotNHSquared * (alpha - 1.0) + 1.0;
	return alpha / (PI * pow2(distr));
}

float schlick(float f0, float nDotV){
	bool checkTIR = false;
	#ifdef WATER_REFRACTION
		checkTIR = true;
	#endif

	if(abs(f0 - 0.02) > 0.001 || !checkTIR){ // if not water don't bother checking for TIR
		return f0 + (1 - f0) * pow(1 - nDotV, 5);
	}

	f0 = pow2(f0);
	if(isEyeInWater == 1.0){
		float sinT2 = pow2(1.33)*(1.0 - pow2(nDotV));
		if(sinT2 > 1.0){
			return 1.0;
		}
		nDotV = sqrt(1.0-sinT2);
	}
	float x = 1.0-nDotV;
	return f0 + (1 - f0) * pow(x, 5);
	
}

// https://www.shadertoy.com/view/DdlGWM
// weird place to get it from, I know
vec3 lazanyi2019(vec3 f0, vec3 f82, float nDotV) {
    // vec3 a = (f0 + (1.-f0)*pow(1.-(1./7.),5.)-f82)/((1./7.)*pow(1.-(1./7.),6.));
    // vec3 a = 7.*(pow(7./6.,6.) * (f0 - f82) + (7./6.) * (1.0 - f0));
    vec3 a = (823543./46656.) * (f0 - f82) + (49./6.) * (1.0 - f0);

    float p1 = 1.0 - nDotV;
    float p2 = p1*p1;
    float p4 = p2*p2;

    return clamp(f0 + ((1.0 - f0) * p1 - a * nDotV * p2) * p4, 0., 1. );
    //return clamp(f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0) - a * cosTheta * pow(1.0 - cosTheta, 6.0),0.,1.);
}

void ComputeSSReflections(io vec3 color, mat2x3 position, vec3 normal, float baseReflectance, float perceptualSmoothness, float skyLightmap, vec3 sunlight) {
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

	float specularHighlight = ggx(n, v, lightVector, max(roughness, 0.0001));
	

	vec3 fresnel;

	if (baseReflectance < (229.5 / 255.0)) {
		fresnel = vec3(schlick(baseReflectance, nDotV));

	} else {
		
		vec3 f0 = getMetalf0(baseReflectance, color); // lazanyi 2019 schlick
		vec3 f82 = getMetalf82(baseReflectance, color);
		fresnel = lazanyi2019(f0, f82, nDotV);
	}

	if(length(fresnel) < 0.01){
		return;
	}


	mat2x3 refRay;
	
	vec3 refCoord;

	int samples = REFLECTION_SAMPLES;

	samples = int(mix(1.0, float(samples), pow3(length(fresnel)))); // reduce samples for weaker reflections
	samples = max(1, samples);
	
	
	float fogFactor = 1.0;
	
	vec3 reflectionSum = vec3(0);
	vec3 offsetNormal = normal;

	refRay[0] = reflect(position[0], offsetNormal);
	refRay[1] = mat3(gbufferModelViewInverse) * refRay[0];

	for(int i = 0; i < samples; i++){
		
		if(roughness > ROUGH_REFLECTION_THRESHOLD){
			break;
		}

		if (roughness > 0){ // rough reflections
			float r1 = ign(floor(gl_FragCoord.xy), frameCounter * samples + i);
			float r2 = ign(floor(gl_FragCoord.xy) + vec2(97, 23), frameCounter * samples + i);

			mat3 tbn = CalculateTBN(normal);
			offsetNormal = tbn * (SampleVNDFGGX(normalize(-position[0] * tbn), vec2(roughness), vec2(r1, r2))); // I should be squaring roughness for alpha but it makes things way too reflective
			
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
			
			#ifndef WORLD_THE_NETHER
			
			in_scatter = SkyAtmosphereToPoint(position[1], mat3(gbufferModelViewInverse) * refVPos, transmit, VL);
			#endif
		} else {
			
			#ifdef WORLD_THE_NETHER
				reflection = mix(color, vec3(0.02, 0.02, 0), 0.5);
			#else
			transmit = vec3(1.0);

			float sunFactor = 0.0;
			in_scatter = ComputeSky(normalize(refRay[1]), position[1], transmit, 1.0, true, sunFactor);

			#ifdef CLOUD3D
				vec2 reflectedTexCoord = ViewSpaceToScreenSpace(refRay[0]);
				if(clamp01(reflectedTexCoord) == reflectedTexCoord){
					vec4 cloud = textureLod(colortex5, reflectedTexCoord, VolCloudLOD);
					cloud.rgb = pow2(cloud.rgb) * 50.0;
					cloud.a = clamp01(mix(cloud.a, 0.0, pow4(length(abs(reflectedTexCoord - 0.5) * 2))));
					in_scatter = mix(in_scatter, cloud.rgb, cloud.a);
				}
			#endif
			

			in_scatter *= (1.0 - float(isEyeInWater == 1.0));

			if(isEyeInWater == 1.0){
				transmit = vec3(1.0);
				reflection = mix(waterColor * sunlightColor, waterColor / 4, 1.0 - skyLightmap) * dot(-normal, lightVector);
			}
			
			#endif
		}
		
		reflection = reflection * transmit + in_scatter;
		if(!hit){
			reflection = mix(reflection, color, 1.0 - skyLightmap); // horrible way to reduce sky reflections without making reflections too dark
		}
		
		reflectionSum += reflection;

		

		if (roughness == 0){
			break;
		}
	}

	
	
	if (roughness > 0){
		reflectionSum /= samples;
	}

	

	vec3 transmit = vec3(1.0);
	vec3 sunspot = sunlightColor * specularHighlight * sunlight;

	if(roughness > ROUGH_REFLECTION_THRESHOLD){
		reflectionSum = color;
	}

	reflectionSum += sunspot;
	
	

	#ifdef MULTIPLY_METAL_ALBEDO
		if (baseReflectance >= (229.5 / 255.0)) {
			reflectionSum *= color;
		}
	#endif
	
	if (baseReflectance < 1.0){
		color = mix(color, reflectionSum, clamp01(fresnel));
	}
	
}


#endif

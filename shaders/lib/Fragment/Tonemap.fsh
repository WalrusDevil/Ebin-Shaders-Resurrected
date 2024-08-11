#if !defined TONEMAP_GLSL
#define TONEMAP_GLSL

#define TONEMAP 3 // [1 2 3 4 5 6]

#if TONEMAP == 2
	#define Tonemap(x) ACESFitted(x)
#elif TONEMAP > 2 && TONEMAP < 6
	#define Tonemap(x) BurgessTonemap(x)
#elif TONEMAP == 4
	#define Tonemap(x) Uncharted2Tonemap(x)
#else
	#define Tonemap(x) ReinhardTonemap(x)
#endif



void ReinhardTonemap(io vec3 color) {
	color *= EXPOSURE;
	color  = color / (color + 1.0);
	color  = pow(color, vec3(1.15 / 2.2));
}

vec3 Curve(vec3 x, vec3 a, vec3 b, vec3 c, vec3 d, vec3 e) {
	x *= max0(a);
	x  = ((x * (c * x + 0.5)) / (x * (c * x + 1.7) + b)) + e;
	x  = pow(x, d);

	return x;
}

void BurgessTonemap(io vec3 color) {
	vec3  a, b, c, d, e, f;
	float g;

	color *= 0.2;

#if TONEMAP == 3 // Default
	a =  3.00 * vec3(1.0, 1.0, 1.0); // Exposure
	b =  1.00 * vec3(1.0, 1.0, 1.0); // Contrast
	c = 12.00 * vec3(1.0, 1.0, 1.0); // Vibrance
	d =  0.42 * vec3(1.0, 1.0, 1.0); // Gamma
	e =  0.00 * vec3(1.0, 1.0, 1.0); // Lift
	f =  1.00 * vec3(1.0, 1.0, 1.0); // Highlights
	g =  1.00; // Saturation
#elif TONEMAP == 4 // Silvia's Ebin preset
	a =  1.50 * vec3(1.00, 1.06, 0.93); // Exposure
	b =  0.60 * vec3(1.00, 1.00, 0.91); // Contrast
	c = 17.00 * vec3(1.00, 1.00, 0.70); // Vibrance
	d =  0.46 * vec3(0.93, 1.00, 1.00); // Gamma
	e =  0.01 * vec3(1.50, 1.00, 1.00); // Lift
	f =  1.00 * vec3(1.00, 1.00, 1.00); // Highlights
	g =  0.93; // Saturation

	e *= smoothstep(0.1, -0.1, worldLightVector.y);
#elif TONEMAP == 5 // Silvia's preferred from continuity
	a =  1.60 * vec3(0.94, 1.00, 1.00); // Exposure
	b =  0.60 * vec3(1.00, 1.00, 1.00); // Contrast
	c = 12.00 * vec3(1.00, 1.00, 1.00); // Vibrance
	d =  0.36 * vec3(0.92, 1.00, 1.00); // Gamma
	e =  0.00 * vec3(1.00, 1.00, 1.00); // Lift
	f =  1.00 * vec3(1.00, 1.00, 1.00); // Highlights
	g = 1.09; // Saturation
#else
	/*
	 * Tweak custom Burgess tonemap HERE
	 */
	a = vec3(1.5, 1.6, 1.6);	//Exposure
	b = vec3(0.6, 0.6, 0.6);	//Contrast
	c = vec3(12.0, 12.0, 12.0);	//Vibrance
	d = vec3(0.33, 0.36, 0.36);	//Gamma
	e = vec3(0.000, 0.000, 0.000);	//Lift
	f = vec3(1.05, 1.02, 1.0);    //Highlights
	g = 1.19;                    //Saturation
#endif

	e *= smoothstep(0.1, -0.1, worldLightVector.y);
	g *= 1.0 - biomePrecipness * 0.2; // reduces saturation in the rain

	color = Curve(color, a, b, c, d, e);

	float luma = dot(color, lumaCoeff);
	color  = mix(vec3(luma), color, g) / Curve(vec3(1.0), a, b, c, d, e);
	color *= f;
}

void Uncharted2Tonemap(io vec3 color) {
	cfloat A = 0.15, B = 0.5, C = 0.1, D = 0.2, E = 0.02, F = 0.3, W = 11.2;
	cfloat whiteScale = 1.0 / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
	cfloat ExposureBias = 2.3 * EXPOSURE;

	vec3 curr = ExposureBias * color;
	     curr = ((curr * (A * curr + C * B) + D * E) / (curr * (A * curr + B) + D * F)) - E / F;

	color = curr * whiteScale;
	color = pow(color, vec3(1.0 / 2.2));
}

const mat3 ACESInputMat = mat3(
	0.59719, 0.35458, 0.04823,
	0.07600, 0.90834, 0.01566,
	0.02840, 0.13383, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
const mat3 ACESOutputMat = mat3(
	1.60475, -0.53108, -0.07367,
	-0.10208,  1.10813, -0.00605,
	-0.00327, -0.07276,  1.07602
);

vec3 RRTAndODTFit(vec3 v) {
	vec3 a = v * (v + 0.0245786f) - 0.000090537f;
	vec3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
	return a / b;
}

void ACESFitted(io vec3 color) {
	color *= EXPOSURE;
	
	const vec3 W = vec3(0.2125, 0.7154, 0.0721);
	color = mix(vec3(dot(color, W)), color, SATURATION);
	
	color = color * ACESInputMat;
	
	
	// Apply RRT and ODT
	color = RRTAndODTFit(color);
	
	color = color * ACESOutputMat;
	
	color = pow(color, vec3(1.0 / 2.2));
}

#endif

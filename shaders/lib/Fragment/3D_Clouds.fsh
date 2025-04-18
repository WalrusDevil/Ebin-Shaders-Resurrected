#include "/lib/Fragment/PrecomputedSky.glsl"

float CalculateDitherPattern1() {
	const int[16] ditherPattern = int[16] (
		 0,  8,  2, 10,
		12,  4, 14,  6,
		 3, 11,  1,  9,
		15,  7, 13,  5);
	
	vec2 count = vec2(mod(gl_FragCoord.st, vec2(4.0)));
	
	int dither = ditherPattern[int(count.x) + int(count.y) * 4] + 1;
	
	return float(dither) / 17.0;
}

float CalculateSunglow2(vec3 vPos) {
	vec3 npos = normalize(vPos);
	vec3 halfVector2 = normalize(-lightVector + npos);
	float factor = 1.0 - dot(halfVector2, npos);
	
	return factor * factor * factor * factor;
}

float Get2DNoise(vec3 pos) { // 2D slices
	return texture(noisetex, pos.xz * noiseResInverse).x;
}

float Get2DStretchNoise(vec3 pos) {
	float zStretch = 15.0 * noiseResInverse;
	
	vec2 coord = pos.xz * noiseResInverse + (floor(pos.y) * zStretch);
	
	return texture(noisetex, coord).x;
}

float Get2_5DNoise(vec3 pos) { // 2.5D
	float p = floor(pos.y);
	float f = pos.y - p;
	
	float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xz * noiseResInverse + (p * zStretch);
	
	vec2 noise = texture(noisetex, coord).xy;
	
	return mix(noise.x, noise.y, f);
}

float Get3DNoise(vec3 pos) { // True 3D
	float p = floor(pos.z);
	float f = pos.z - p;
	
	float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xy * noiseResInverse + (p * zStretch);
	
	float xy1 = texture(noisetex, coord).x;
	float xy2 = texture(noisetex, coord + zStretch).x;
	
	return mix(xy1, xy2, f);
}

vec3 Get3DNoise3D(vec3 pos) {
	float p = floor(pos.z);
	float f = pos.z - p;
	
	float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xy * noiseResInverse + (p * zStretch);
	
	vec3 xy1 = texture(noisetex, coord).xyz;
	vec3 xy2 = texture(noisetex, coord + zStretch).xyz;
	
	return mix(xy1, xy2, f);
}

#define CloudNoise Get3DNoise // [Get2DNoise Get2DStretchNoise Get2_5DNoise Get3DNoise]

float GetCoverage(float coverage, float denseFactor, float clouds) {
	return clamp01((clouds + coverage - 1.0) * denseFactor);
}

mat4x3 cloudMul;
mat4x3 cloudAdd;

vec3 directColor, ambientColor, bouncedColor;

vec4 CloudColor(vec3 worldPosition, float cloudLowerHeight, float cloudDepth, float denseFactor, float coverage, float sunglow) {
	float cloudCenter = cloudLowerHeight + cloudDepth * 0.5;
	
	float cloudAltitudeWeight = clamp01(distance(worldPosition.y, cloudCenter) / (cloudDepth / 2.0));
	      cloudAltitudeWeight = pow(1.0 - cloudAltitudeWeight, 0.33);
	
	vec4 cloud;
	
	mat4x3 p;
	
	float[5] weights = float[5](1.3, -0.7, -0.255, -0.105, 0.04);
	
	vec3 w = worldPosition / 100.0;
	
	p[0] = w * cloudMul[0] + cloudAdd[0];
	p[1] = w * cloudMul[1] + cloudAdd[1];
	
	cloud.a  = CloudNoise(p[0]) * weights[0];
	cloud.a += CloudNoise(p[1]) * weights[1];
	
	if (GetCoverage(coverage, denseFactor, (cloud.a - weights[1]) * cloudAltitudeWeight) < 1.0)
		return vec4(0.0);
	
	p[2] = w * cloudMul[2] + cloudAdd[2];
	p[3] = w * cloudMul[3] + cloudAdd[3];
	
	cloud.a += CloudNoise(p[2]) * weights[2];
	cloud.a += CloudNoise(p[3]) * weights[3];
	cloud.a += CloudNoise(p[3] * cloudMul[3] / 6.0 + cloudAdd[3]) * weights[4];
	
	cloud.a += -(weights[1] + weights[2] + weights[3]);
	cloud.a /= 2.15;
	
	cloud.a = GetCoverage(coverage, denseFactor, cloud.a * cloudAltitudeWeight);
	
	float heightGradient  = clamp01((worldPosition.y - cloudLowerHeight) / cloudDepth);
	float anisoBackFactor = mix(clamp01(pow(cloud.a, 1.6) * 2.5), 1.0, sunglow);
	float sunlight;
	
	// /*
	// vec3 lightOffset = 0.25 * worldLightVector;
	
	// cloudAltitudeWeight = clamp01(distance(worldPosition.y + lightOffset.y * cloudDepth, cloudCenter) / (cloudDepth / 2.0));
	// cloudAltitudeWeight = pow(1.0 - cloudAltitudeWeight, 0.3);
	
	// sunlight  = CloudNoise(p[0] + lightOffset) * weights[0];
	// sunlight += CloudNoise(p[1] + lightOffset) * weights[1];
	// if (1.0 - GetCoverage(coverage, denseFactor, (sunlight - weights[1]) * cloudAltitudeWeight) < 1.0)
	// {
	// sunlight += CloudNoise(p[2] + lightOffset) * weights[2];
	// sunlight += CloudNoise(p[3] + lightOffset) * weights[3];
	// sunlight += -(weights[1] + weights[2] + weights[3]); }
	// sunlight /= 2.15;
	// sunlight  = 1.0 - pow(GetCoverage(coverage, denseFactor, sunlight * cloudAltitudeWeight), 1.5);
	// sunlight  = (pow4(heightGradient) + sunlight * 0.9 + 0.1) * (1.0 - timeHorizon);
	// */
	
	sunlight  = pow5((worldPosition.y - cloudLowerHeight) / (cloudDepth - 25.0)) + sunglow * 0.005;
	sunlight *= 1.0 + sunglow * 5.0 + pow(sunglow, 0.25);
	
	
	cloud.rgb = mix(ambientColor, directColor, sunlight) + bouncedColor;
	
	return cloud;
}

void swap(io vec3 a, io vec3 b) {
	vec3 swap = a;
	a = b;
	b = swap;
}

void CloudFBM1(float speed) {
	float t = TIME * 0.07 * speed;
	
	cloudMul[0] = vec3(0.5, 0.5, 0.1);
	cloudAdd[0] = vec3(t * 1.0, 0.0, 0.0);
	
	cloudMul[1] = vec3(1.0, 2.0, 1.0);
	cloudAdd[1] = vec3(t * 0.577, 0.0, 0.0);
	
	cloudMul[2] = vec3(6.0, 6.0, 6.0);
	cloudAdd[2] = vec3(t * 5.272, 0.0, t * 0.905);
	
	cloudMul[3] = vec3(18.0);
	cloudAdd[3] = vec3(t * 19.721, 0.0, t * 6.62);
}

void CloudLighting1(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 8.0 * (1.0 + pow4(sunglow) * 10.0) * (1.0 - biomePrecipness * 0.8);
	
	ambientColor  = mix(sqrt(skylightColor), sunlightColor, 0.15);
	ambientColor *= 2.0 * mix(vec3(1.0), vec3(0.6, 0.8, 1.0), timeNight);
	
	bouncedColor = mix(skylightColor, sunlightColor, 0.5);
}

void CloudLighting2(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 35.0 * (1.0 + pow2(sunglow) * 2.0) * mix(1.0, 0.2, biomePrecipness);
	
	ambientColor  = mix(sqrt(skylightColor), sunlightColor, 0.5);
	ambientColor *= 0.5 + timeHorizon * 0.5;
	
	directColor += ambientColor * 20.0 * timeHorizon;
	
	bouncedColor = vec3(0.0);
}

void CloudLighting3(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 140.0 * mix(1.0, 0.5, timeNight) * (1.0 - biomePrecipness * 0.8);
	
	ambientColor = mix(skylightColor, sunlightColor, 0.15) * 7.0;
	
	bouncedColor = vec3(0.0);
}

#if CLOUD3D_LIGHTING == 1
	#define CloudLighting(x) CloudLighting1(x)
#elif CLOUD3D_LIGHTING == 2
	#define CloudLighting(x) CloudLighting2(x)
#else
	#define CloudLighting(x) CloudLighting3(x)
#endif


void RaymarchClouds(io vec4 cloud, vec3 position, float sunglow, float samples, float density, float coverage, float cloudLowerHeight, float cloudDepth) {
	if (cloud.a >= 1.0) return;

	float cloudUpperHeight = cloudLowerHeight + cloudDepth;
	
	vec3 a, b, rayPosition, rayIncrement; // we trace from a to b
	
	float upperScale = ((cloudUpperHeight - cameraPosition.y) / position.y);
	float lowerScale = ((cloudLowerHeight - cameraPosition.y) / position.y);

		// we min with 1 to prevent positions inside the cloud volume from being scaled to be outside it (stops clouds rendering on top of stuff)
	if(length(position) < far){
		upperScale = min(upperScale, 1.0);
		lowerScale = min(lowerScale, 1.0);
	}

	a = position * upperScale; // where ray intersects with top of cloud layer
	b = position * lowerScale; // where ray intersects with bottom of cloud layer
	
	if (cameraPosition.y < cloudLowerHeight) { // camera is below the cloud volume
		if (position.y <= 0.0) return; // if the ray is moving downwards it will never hit the volume
		
		swap(a, b); // ray enters at bottom of cloud layer so make the bottom the entry point
	} else if (cloudLowerHeight <= cameraPosition.y && cameraPosition.y <= cloudUpperHeight) { // camera is within the cloud layer
		if (position.y < 0.0) swap(a, b); // if the ray is moving downwards, swap before to cancel the later swap
		
		//samples *= abs(a.y) / cloudDepth; // reduce samples within clouds
		b = vec3(0.0); // we are about to swap, so we trace from the camera's position which is 0,0,0
		
		swap(a, b);
	} else { // camera is above the cloud volume
		if (position.y >= 0.0) return; // ray is moving upwards so it will never hit the volume
	}

	float dither = InterleavedGradientNoise(floor(gl_FragCoord.xy));

	
	rayIncrement = (b - a) / (samples + 1.0);

	rayPosition = a + cameraPosition + rayIncrement * (1.0 + dither);


	
	coverage *= clamp01(1.0 - length2((rayPosition.xz - cameraPosition.xz) / 10000.0));
	if (coverage <= 0.1) return;
	
	float denseFactor = 1.0 / (1.0 - density);

	for (float i = 0.0; i < samples && cloud.a < 1.0; i++,rayPosition += rayIncrement) {
		vec4 cloudSample = CloudColor(rayPosition, cloudLowerHeight, cloudDepth, denseFactor, coverage, sunglow);
		
		if(cameraPosition.y < cloudLowerHeight || cameraPosition.y > cloudUpperHeight){
			cloudSample.a = mix(cloudSample.a, 0.0, sqrt(clamp01(length(rayPosition.xz - cameraPosition.xz) / 8000))); // fade clouds with distance
		}
		
		cloud.rgb += cloudSample.rgb * (1.0 - cloud.a) * cloudSample.a;
		cloud.a += cloudSample.a;
	}

	cloud.a = clamp01(cloud.a);
}



vec4 CalculateClouds3(vec3 wPos, float depth) {
#ifndef CLOUD3D
	return vec4(0.0);
#endif
	
	// if (depth < 1.0) return vec4(0.0);
	const ivec2[4] offsets = ivec2[4](ivec2(2), ivec2(-2, 2), ivec2(2, -2), ivec2(-2));

	
	// I think this just checks if the pixel is surrounded by pixels where clouds should not be computed
	// if (all(lessThan(textureGatherOffsets(depthtex1, texcoord, offsets, 0), vec4(1.0)))) return vec4(0.0);
	
	float sunglow  = pow8(clamp01(dotNorm(wPos, worldLightVector) - 0.01)) * pow4(max(timeDay, timeNight));
	// sunglow = mix(sunglow, 0.0, biomePrecipness);

	float coverage = 0.0;
	
	vec4 cloudSum = vec4(0.0);
	
	coverage = CLOUD3D_COVERAGE + biomePrecipness * 0.335;
	#ifdef BIOME_WEATHER
	coverage += -0.2 + (0.15 * humiditySmooth);
	#endif

	CloudFBM1(CLOUD3D_SPEED);
	CloudLighting(sunglow);
	RaymarchClouds(cloudSum, wPos, sunglow, CLOUD3D_SAMPLES, CLOUD3D_DENSITY, coverage, CLOUD3D_START_HEIGHT, CLOUD3D_DEPTH);
	
	cloudSum.rgb *= 0.1;

	// the clouds look like ass if I leave them as default but mixing them with the sky makes them look decent
	// however, since the sky has the sun in it, it always shines through the clouds, so we precalculate the sky without the sun and blend with that instead
	// TODO: good clouds
	vec3 transmit = vec3(1.0);
	cloudSum.rgb = mix(cloudSum.rgb, SkyAtmosphere(normalize(wPos), transmit), 0.5);
	
	return cloudSum;
}

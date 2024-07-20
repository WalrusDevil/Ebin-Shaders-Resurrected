cfloat PI  = radians(180.0);
cfloat HPI = radians( 90.0);
cfloat TAU = radians(360.0);
cfloat RAD = radians(  1.0); // Degrees per radian
cfloat DEG = degrees(  1.0); // Radians per degree

uniform int   frameCounter;
uniform float frameTimeCounter;

//#define FREEZE_TIME
//#define FRAMERATE_BOUND_TIME
#define ANIMATION_FRAMERATE 60.0 // [24.0 30.0 60.0 120.0 90.0 144.0 240.0]

#ifdef FREEZE_TIME
	cfloat TIME = 0.0;
#else
	#ifdef FRAMERATE_BOUND_TIME
		float TIME = frameCounter / float(ANIMATION_FRAMERATE);
	#else
		float TIME = frameTimeCounter;
	#endif
#endif

cvec4 swizzle = vec4(1.0, 0.0, -1.0, 0.5);

#define sum4(v) (((v).x + (v).y) + ((v).z + (v).w))

#define diagonal2(mat) vec2((mat)[0].x, (mat)[1].y)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, mat[2].z)

#define transMAD(mat, v) (     mat3(mat) * (v) + (mat)[3].xyz)
#define  projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define textureRaw(samplr, coord) texelFetch(samplr, ivec2((coord) * vec2(viewWidth, viewHeight)), 0)
#define ScreenTex(samplr) texelFetch(samplr, ivec2(gl_FragCoord.st), 0)

#if !defined gbuffers_shadow
	#define cameraPos (cameraPosition + gbufferModelViewInverse[3].xyz)
#else
	#define cameraPos (cameraPosition)
#endif

#define rcp(x) (1.0 / (x))


#include "/lib/Utility/boolean.glsl"

#include "/lib/Utility/pow.glsl"

#include "/lib/Utility/fastMath.glsl"

#include "/lib/Utility/lengthDotNormalize.glsl"

#include "/lib/Utility/clamping.glsl"

#include "/lib/Utility/encoding.glsl"

#include "/lib/Utility/blending.glsl"


// Applies a subtle S-shaped curve, domain [0 to 1]
#define cubesmooth_(type) type cubesmooth(type x) { return (x * x) * (3.0 - 2.0 * x); }
DEFINE_genFType(cubesmooth_)

#define cosmooth_(type) type cosmooth(type x) { return 0.5 - cos(x * PI) * 0.5; }
DEFINE_genFType(cosmooth_)

vec2 rotate(in vec2 vector, float radians) {
	return vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}

vec2 clampScreen(vec2 coord, vec2 pixel) {
	return clamp(coord, pixel, 1.0 - pixel);
}

cvec3 lumaCoeff = vec3(0.2125, 0.7154, 0.0721);
vec3  SetSaturationLevel(vec3 color, float level) {
	float luminance = dot(color, lumaCoeff);
	vec3 newColor = max0(mix(vec3(luminance), color, level));
	
	return newColor;
}

vec3 hsv(vec3 c) {
	cvec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 rgb(vec3 c) {
	cvec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	
	return c.z * mix(K.xxx, clamp01(p - K.xxx), c.y);
}

float getLuminance(vec3 color) {
	return dot(color, lumaCoeff);
}

// https://www.shadertoy.com/view/4sV3zt
vec3 slerp(vec3 start, vec3 end, float percent)
{
     float dot = dot(start, end);     
     dot = clamp(dot, -1.0, 1.0);
     float theta = acos(dot) * percent;
     vec3 relativeVec = normalize(end - start*dot); // Orthonormal basis
     // The final result.
     return ((start * cos(theta)) + (relativeVec * sin(theta)));
}

//Dithering from Jodie
float bayer2(vec2 a) {
		a = floor(a);
		return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

#define bayer4(a) (bayer2(a * 0.5) * 0.25 + bayer2(a))
#define bayer8(a) (bayer4(a * 0.5) * 0.25 + bayer2(a))

// https://www.shadertoy.com/view/ssBBW1
// ---------------------------------------
uint HilbertIndex(uvec2 p) {
    uint i = 0u;
    for(uint l = 0x4000u; l > 0u; l >>= 1u) {
        uvec2 r = min(p & l, 1u);
        
        i = (i << 2u) | ((r.x * 3u) ^ r.y);       
        p = r.y == 0u ? (0x7FFFu * r.x) ^ p.yx : p;
    }
    return i;
}

uint ReverseBits(uint x) {
    x = ((x & 0xaaaaaaaau) >> 1) | ((x & 0x55555555u) << 1);
    x = ((x & 0xccccccccu) >> 2) | ((x & 0x33333333u) << 2);
    x = ((x & 0xf0f0f0f0u) >> 4) | ((x & 0x0f0f0f0fu) << 4);
    x = ((x & 0xff00ff00u) >> 8) | ((x & 0x00ff00ffu) << 8);
    return (x >> 16) | (x << 16);
}

// from: https://psychopath.io/post/2021_01_30_building_a_better_lk_hash
uint OwenHash(uint x, uint seed) { // seed is any random number
    x ^= x * 0x3d20adeau;
    x += seed;
    x *= (seed >> 16) | 1u;
    x ^= x * 0x05526c56u;
    x ^= x * 0x53a22864u;
    return x;
}

// adapted from: https://www.shadertoy.com/view/MslGR8
float ReshapeUniformToTriangle(float v) {
    v = v * 2.0 - 1.0;
    v = sign(v) * (1.0 - sqrt(max(0.0, 1.0 - abs(v)))); // [-1, 1], max prevents NaNs
    return v + 0.5; // [-0.5, 1.5]
}

float blueNoise(vec2 coord){
	uint m = HilbertIndex(uvec2(coord));
	m = OwenHash(ReverseBits(m), 0xe7843fbfu);
	m = OwenHash(ReverseBits(m), 0x8d8fb1e0u);
	float mask = float(ReverseBits(m)) / 4294967296.0;

	mask = ReshapeUniformToTriangle(mask);
	return mask;
}
// ---------------------------------------

// https://blog.demofox.org/2022/01/01/interleaved-gradient-noise-a-different-kind-of-low-discrepancy-sequence/
// adapted with help from balint and hardester
float ign(vec2 coord){
	return fract(52.9829189 * fract(0.06711056 * coord.x + (0.00583715 * coord.y)));
}

float ign(vec2 coord, int frame){
	return ign(coord + 5.588238 * (frame & 63));
}

#ifdef fsh
float linearizeDepth(float depth) {
	return (2.0 * near) / (far + near - depth * (far - near));
}
#endif


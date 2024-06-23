#include "/lib/Syntax.glsl"


varying vec2 texcoord;

#include "/lib/Uniform/Shading_Variables.glsl"


/***********************************************************************/
#if defined vsh

uniform sampler3D colortex7;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float far;

uniform float rainStrength;
uniform float wetness;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"
#include "/UserProgram/centerDepthSmooth.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.vsh"
#include "/lib/Fragment/PrecomputedSky.glsl"
#include "/lib/Vertex/Shading_Setup.vsh"

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	//gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * COMPOSITE0_SCALE) * 2.0 - 1.0;
	
	
	SetupProjection();
	SetupShading();
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh


const bool shadowtex1Mipmap    = true;
const bool shadowcolor0Mipmap  = true;
const bool shadowcolor1Mipmap  = true;

const bool shadowtex1Nearest   = true;
const bool shadowcolor0Nearest = true;
const bool shadowcolor1Nearest = false;

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

uniform int isEyeInWater;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Masks.fsh"

float GetDepth(vec2 coord) {
	return textureRaw(gdepthtex, coord).x;
}

float GetDepthLinear(vec2 coord) {
	return (near * far) / (textureRaw(gdepthtex, coord).x * (near - far) + far);
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}

vec3 GetNormal(vec2 coord) {
	return DecodeNormal(textureRaw(colortex4, coord).xy);
}


vec2 GetDitherred2DNoise(vec2 coord, float n) { // Returns a random noise pattern ranging {-1.0 to 1.0} that repeats every n pixels
	coord *= vec2(viewWidth, viewHeight);
	coord  = mod(coord, vec2(n));
	return texelFetch(noisetex, ivec2(coord), 0).xy;
}

float ExpToLinearDepth(float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

//Dithering from Jodie
float Bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

#define Bayer4(a) (Bayer2(a * 0.5) * 0.25 + Bayer2(a))
#define Bayer8(a) (Bayer4(a * 0.5) * 0.25 + Bayer2(a))


// from BSL
vec2 Reprojection(vec3 pos) {
	pos = pos * 2.0 - 1.0;

	vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
	viewPosPrev /= viewPosPrev.w;
	viewPosPrev = gbufferModelViewInverse * viewPosPrev;

	vec3 cameraOffset = cameraPosition - previousCameraPosition;
	cameraOffset *= float(pos.z > 0.56);

	vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
}

vec2 OffsetDist(float x) {
	float n = fract(x * 8.0) * 6.283;
    return vec2(cos(n), sin(n)) * x * x;
}

vec3 GetMultiColoredBlocklight(vec2 coord, float z, float dither) {
	vec2 prevCoord = Reprojection(vec3(coord, z));
	float lz = GetLinearDepth(z);

	float distScale = clamp((far - near) * lz + near, 4.0, 128.0);
	float fovScale = gbufferProjection[1][1] / 1.37;

	vec2 blurstr = vec2(1.0 / aspectRatio, 1.0) * 2.5 * fovScale / distScale;
	
	vec3 lightAlbedo = texture2D(colortex11, coord).rgb;
	vec3 previousColoredLight = vec3(0.0);

	// #ifdef MCBL_ANTI_BLEED
	float linearZ = GetLinearDepth(z);
	// #endif

	float mask = clamp(2.0 - 2.0 * max(abs(prevCoord.x - 0.5), abs(prevCoord.y - 0.5)), 0.0, 1.0);

	for(int i = 0; i < 4; i++) {
		vec2 offset = OffsetDist((dither + i) * 0.25) * blurstr;
		offset = floor(offset * vec2(viewWidth, viewHeight) + 0.5) / vec2(viewWidth, viewHeight);

		// #ifdef MCBL_ANTI_BLEED
		vec2 sampleZPos = coord + offset;
		float sampleZ0 = texture2D(depthtex0, sampleZPos).r;
		float sampleZ1 = texture2D(depthtex1, sampleZPos).r;
		float linearSampleZ = GetLinearDepth(sampleZ1 >= 1.0 ? sampleZ0 : sampleZ1);

		float sampleWeight = clamp(abs(linearZ - linearSampleZ) * far / 16.0, 0.0, 1.0);
		sampleWeight = 1.0 - sampleWeight * sampleWeight;
		// #else
		// float sampleWeight = 1.0;
		// #endif

		previousColoredLight += texture2D(colortex12, prevCoord.xy + offset).rgb * sampleWeight;
	}

	previousColoredLight *= 0.25;
	previousColoredLight *= previousColoredLight * mask;

	return sqrt(mix(previousColoredLight, lightAlbedo * lightAlbedo / 0.1, 0.1));
}

#include "/lib/Fragment/ComputeGI.fsh"
#include "/lib/Fragment/ComputeSSAO.fsh"
#include "/lib/Fragment/ComputeVolumetricLight.fsh"

/* RENDERTARGETS:5,6,12 */
#include "/lib/Exit.glsl"

void main() {
	float depth0 = GetDepth(texcoord);
	
#ifndef VOLUMETRIC_LIGHT
	if (depth0 >= 1.0) { discard; }
#endif
	
	
#ifdef COMPOSITE0_NOISE
	vec2 noise2D = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 4.0) * 2.0 - 1.0;
#else
	vec2 noise2D = vec2(0.0);
#endif
	
	vec2 texture4 = textureRaw(colortex4, texcoord).rg;
	
	vec4  decode4       = Decode4x8F(texture4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float specularity    = decode4.g;
	float torchLightmap = decode4.b;
	float skyLightmap   = decode4.a;
	
	float depth1 = (mask.hand > 0.5 ? depth0 : textureRaw(depthtex1, texcoord).x);
	
	mat2x3 backPos;
	backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
	backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
	
	mat2x3 frontPos;
	frontPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth0));
	frontPos[1] = mat3(gbufferModelViewInverse) * frontPos[0];
	
	if (depth0 != depth1)
		mask.water = Decode4x8F(texture2D(colortex0, texcoord).r).b;
	
	vec2 VL = ComputeVolumetricLight(backPos[1], frontPos[1], noise2D, mask.water);
	
	gl_FragData[1] = vec4(VL, 0.0, 0.0);
	
	if (depth1 >= 1.0) // Back surface is sky
		{ gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); exit(); return; }
	
	
	vec3 normal = DecodeNormal(texture4.g, 11);
	
	float AO = ComputeSSAO(backPos[0], normal * mat3(gbufferModelViewInverse));
	
	if (isEyeInWater != mask.water) // If surface is in water
		{ gl_FragData[0] = vec4(0.0, 0.0, 0.0, AO); exit(); return; }
	
	
	vec3 GI = ComputeGI(backPos[1], normal, skyLightmap, GI_RADIUS * 2.0, noise2D, mask);
	
	gl_FragData[0] = vec4(sqrt(GI * 0.2), AO);

	vec3 blockLightColor = GetMultiColoredBlocklight(texcoord, depth0, Bayer8(gl_FragCoord.xy));

	if(blockLightColor == vec3(0.0)){
		gl_FragData[2] = vec4(0.0);
	} else {
		gl_FragData[2] = vec4(blockLightColor, 1.0);
	}

	
	
	exit();
}

#endif
/***********************************************************************/

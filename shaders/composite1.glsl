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
	
	SetupProjection();
	SetupShading();
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

#include "/lib/Settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler3D colortex7;
uniform sampler2D colortex9;
uniform sampler2D colortex10;

#if defined COMPOSITE0_ENABLED
const bool colortex5MipmapEnabled = true;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
#endif

uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D colortex11;
uniform sampler2D colortex12;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 previousCameraPosition;
uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform vec2 pixelSize;
uniform float aspectRatio;

uniform float viewWidth;
uniform float viewHeight;
uniform float wetness;
uniform float rainStrength;
uniform float nightVision;
uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Masks.fsh"

//#include "/UserProgram/centerDepthSmooth.glsl" // Doesn't seem to be enabled unless it's initialized in a fragment.

vec3 GetDiffuse(vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(vec2 coord) {
	return texture2D(depthtex1, coord).x;
}


float ExpToLinearDepth(float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}



#include "/lib/Fragment/ColoredBlockLight.fsh"
#include "/lib/Fragment/ComputeShadedFragment.fsh"



#include "/lib/Fragment/BilateralUpsample.fsh"

#include "/lib/Misc/CalculateFogfactor.glsl"
#include "/lib/Fragment/WaterDepthFog.fsh"

/* RENDERTARGETS:1,4,6,5 */
#include "/lib/Exit.glsl"

void main() {
	vec2 texture4 = ScreenTex(colortex4).rg;
	
	vec4  decode4       = Decode4x8F(texture4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float directionalLightingFactor    = decode4.g;
	float torchLightmap = decode4.b;
	float skyLightmap   = decode4.a;
	float emission			= texture(colortex9, texcoord).b;
	float materialAO		= clamp01(texture(colortex4, texcoord).b);

	vec3 preAcidWorldSpacePosition = texture(colortex10, texcoord).rgb;
	
	float depth0 = (mask.hand > 0.5 ? 0.9 : GetDepth(texcoord));

	torchLightmap *= directionalLightingFactor;

	#ifdef COLORED_BLOCKLIGHT
	blockLightOverrideColor = getColoredBlockLight(torchColor, vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z));
	#endif
	
	vec3 wNormal = DecodeNormal(texture4.g, 11);
	vec3 normal  = wNormal * mat3(gbufferModelViewInverse);
	
	float depth1 = mask.hand > 0.5 ? depth0 : GetTransparentDepth(texcoord);
	
	if (depth0 != depth1) {
		vec2 texture0 = texture2D(colortex0, texcoord).rg;
		
		vec4 decode0 = Decode4x8F(texture0.r);
		
		mask.transparent = 1.0;
		mask.water       = decode0.b;
		mask.bits.xy     = vec2(mask.transparent, mask.water);
		mask.materialIDs = EncodeMaterialIDs(1.0, mask.bits);

		texture4 = vec2(Encode4x8F(vec4(mask.materialIDs, decode0.r, 0.0, decode0.g)), texture0.g);
	}
	
	vec4 GI; vec2 VL;
	BilateralUpsample(wNormal, depth1, GI, VL);
	
	gl_FragData[1] = vec4(texture4.rg, 0.0, 1.0);
	gl_FragData[2] = vec4(VL.xy, 0.0, 1.0);
	
	
	mat2x3 backPos;
	backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
	backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
	
	if (depth1 - mask.hand >= 1.0) {
		 exit(); 
		 return; 
	}
	
	
	vec3 diffuse = GetDiffuse(texcoord);
	vec3 viewSpacePosition0 = CalculateViewSpacePosition(vec3(texcoord, depth0));
	
	
	vec3 composite = ComputeShadedFragment(powf(diffuse, 2.2), mask, torchLightmap, skyLightmap, GI, normal, emission, backPos, materialAO, preAcidWorldSpacePosition);
	
	gl_FragData[0] = vec4(max0(composite), 1.0);
	
	exit();
}

#endif
/***********************************************************************/

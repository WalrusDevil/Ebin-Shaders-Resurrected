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

uniform sampler3D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex10;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;
uniform sampler2D shadowcolor0;
uniform mat4 gbufferModelView;
uniform sampler2D colortex13;
uniform usampler2D waterDepthTex;
uniform usampler2D waterNormalTex;

uniform vec3 shadowLightPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform vec2 pixelSize;
uniform float viewWidth;
uniform float viewHeight;

uniform float rainStrength;
uniform float wetness;

uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;

uniform vec3 fogColor;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Masks.fsh"
#include "/lib/Misc/CalculateFogfactor.glsl"

//const bool colortex1MipmapEnabled = true;

vec3 GetColor(vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}



float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}

vec2 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return (diagonal2(projMatrix) * viewSpacePosition.xy + projMatrix[3].xy) / -viewSpacePosition.z * 0.5 + 0.5;
}

float depth0;
float depth1;
float skyLightmap;

#include "/lib/Fragment/waterdepthFog.fsh"
#include "/lib/Fragment/ComputeSunlight.fsh"
#include "/lib/Fragment/Sky.fsh"
#include "/lib/Fragment/ComputeSSReflections.fsh"
#include "/lib/Fragment/ComputeWaveNormals.fsh"



/* DRAWBUFFERS:32 */
#include "/lib/Exit.glsl"

void main() {
	vec2 texture4 = ScreenTex(colortex4).rg;
	
	vec4  decode4       = Decode4x8F(texture4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float specularity    = decode4.g;
	float baseReflectance = ScreenTex(colortex9).g;
	float perceptualSmoothness = ScreenTex(colortex9).r;
	skyLightmap   = decode4.a;
	vec4 transparentColor = texture(colortex3, texcoord);
	mask.transparent = clamp01(step(0.01, transparentColor.a) + mask.water);
	mask.transparent *= (1.0 - mask.hand);

	float waterDepth = uintBitsToFloat(texture(waterDepthTex, texcoord).r);

	gl_FragData[1] = vec4(decode4.r, 0.0, 0.0, 1.0);
	
	depth0 = GetDepth(texcoord);

	if(depth0 < 0.56){
		mask.hand = 1.0;
		depth0 = 0.55;
	}

	depth1 = (mask.hand > 0.5 ? 0.55 : GetTransparentDepth(texcoord));
	
	vec3 normal = DecodeNormal(texture4.g, 11) * mat3(gbufferModelViewInverse);
	
	mat2x3 frontPos;
	frontPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth0));
	frontPos[1] = mat3(gbufferModelViewInverse) * frontPos[0];
	
	mat2x3 backPos = frontPos;
	if(mask.transparent == 1.0){
		backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
		backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
		baseReflectance = ScreenTex(colortex8).g;
		perceptualSmoothness = ScreenTex(colortex8).r;
	}

	mat2x3 waterPos;
	waterPos[0] = CalculateViewSpacePosition(vec3(texcoord, waterDepth > depth1 ? depth1 : waterDepth));
	
	waterPos[1] = mat3(gbufferModelViewInverse) * waterPos[0];
	
	vec3 color = texture(colortex1, texcoord).rgb;

	#ifdef WATER_REFRACTION
	if(mask.water > 0.5){
		vec3 refracted = normalize(refract(frontPos[0], normal, isEyeInWater == 1.0 ? 1.33 : (1.0 / 1.33)));

		vec3 refractedPos;
		bool refractHit = ComputeSSRaytrace(frontPos[0], refracted, refractedPos);

		if(refractHit){
			depth1 = refractedPos.z;
			backPos[0] = CalculateViewSpacePosition(refractedPos);
			backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
			color = texture(colortex1, refractedPos.xy).rgb;
		} else if(isEyeInWater == 1.0 && EBS == 1.0) {
			color = normalize(waterColor);
			depth1 = 1.0;
			backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
			backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
		}
	}
	#endif

	

	// render sky
	if(depth1 == 1.0) {

		vec3 transmit = vec3(1.0);

		vec3 incident = normalize(frontPos[1]);
		vec3 refracted = incident;
		if(mask.water > 0.5){
			#ifdef WATER_REFRACTION
			refracted = refract(incident, normalize(mat3(gbufferModelViewInverse) * normal), isEyeInWater == 1.0 ? 1.33 : 1.0 / 1.33);
			#endif
		}

		color = ComputeSky(refracted, vec3(0.0), transmit, 1.0, false, 1.0);

	}

	#ifdef WORLD_OVERWORLD
	// apply atmospheric fog to solid things
	if(((mask.water == 0.0 && isEyeInWater == 0.0) || (mask.water == 1.0 && isEyeInWater == 1.0)) && depth1 != 1.0){ // surface not behind water so apply atmospheric fog
		vec3 fogTransmit = vec3(1.0);
		vec3 fog = SkyAtmosphereToPoint(vec3(0.0), backPos[1], fogTransmit);
		color = mix(fog, color, fogTransmit);
	}
	#else
		color = mix(color, fogColor, vec3(CalculateFogFactor(backPos[1])));
	#endif


	#ifdef WATER_BEHIND_TRANSLUCENTS
	if(depth1 > waterDepth && waterDepth != 0.0 && (waterDepth > depth0 || (mask.water < 0.5 && depth0 == waterDepth)) && isEyeInWater == 0.0){ // render water behind translucents when necessary
		color = waterdepthFog(waterPos[0], backPos[0], color);
		vec3 waterNormal = normalize(DecodeNormal(uintBitsToFloat(texture(waterNormalTex, texcoord).r), 11));
		ComputeSSReflections(color, waterPos, waterNormal * mat3(gbufferModelViewInverse), 0.02, 1.0, skyLightmap);
		vec3 fogTransmit = vec3(1.0);
		vec3 fog = SkyAtmosphereToPoint(vec3(0.0), waterPos[1], fogTransmit);
		color = mix(fog, color, fogTransmit);
	} else
	#endif
	if(isEyeInWater == 0.0 && mask.water == 1.0 && mask.hand == 0.0){ // render water fog directly
		color = waterdepthFog(frontPos[0], backPos[0], color);

	}

	// blend in transparent stuff
	color = mix(color, transparentColor.rgb, transparentColor.a);

	ComputeSSReflections(color, frontPos, normal, baseReflectance, perceptualSmoothness, skyLightmap);



	if(isEyeInWater != 0.0){ // surface in water
		color = waterdepthFog(frontPos[0], backPos[0], color);
	}
	
	#ifdef WORLD_OVERWORLD
	if(mask.transparent == 1.0 && isEyeInWater == 0.0){
		vec3 fogTransmit = vec3(1.0);
		vec3 fog = SkyAtmosphereToPoint(vec3(0.0), frontPos[1], fogTransmit);
		color = mix(fog, color, fogTransmit);
	}
	#else
		if(mask.transparent == 1.0) color = mix(color, fogColor, vec3(CalculateFogFactor(frontPos[1])));
	#endif
		
	gl_FragData[0] = vec4(clamp01(EncodeColor(color)), 1.0);
	exit();
}

#endif
/***********************************************************************/

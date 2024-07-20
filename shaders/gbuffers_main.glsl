#include "/lib/Syntax.glsl"

#define gbuffers_main

varying vec3 color;
varying vec2 texcoord;
varying vec2 vertLightmap;
flat varying ivec2 textureResolution;

varying mat3 tbnMatrix;

varying mat2x3 position;

varying vec3 worldDisplacement;

flat varying float materialIDs;

varying float blocklight;



#include "/lib/Uniform/Shading_Variables.glsl"


/***********************************************************************/
#if defined vsh

attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec2 mc_midTexCoord;
attribute vec4 at_midBlock;

uniform float rainStrength;
uniform float thunderStrength;

uniform sampler2D lightmap;

uniform mat4 gbufferModelViewInverse;

uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform float far;

uniform float wetness;

#include "/lib/iPBR/IDs.glsl"
#include "/lib/iPBR/Groups.glsl"
#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"

#if defined gbuffers_water || defined gbuffers_textured
uniform sampler3D gaux1;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform float sunAngle;

#include "/UserProgram/centerDepthSmooth.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.vsh"
#include "/lib/Fragment/PrecomputedSky.glsl"
#include "/lib/Vertex/Shading_Setup.vsh"
#endif


vec2 GetDefaultLightmap() {
	vec2 lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	return clamp01(lightmapCoord / vec2(0.8745, 0.9373)).rg;
}

vec3 GetWorldSpacePosition() {
	vec3 position = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
	
#if  defined gbuffers_water || defined gbuffers_textured
	position -= gl_NormalMatrix * gl_Normal * (norm(gl_Normal) * 0.00005 * float(abs(mc_Entity.x - 8.5) > 0.6));
#elif defined gbuffers_spidereyes
	position += gl_NormalMatrix * gl_Normal * (norm(gl_Normal) * 0.0002);
#endif
	
	return mat3(gbufferModelViewInverse) * position;
}

vec4 ProjectViewSpace(vec3 viewSpacePosition) {
#if !defined gbuffers_hand
	return vec4(projMAD(projMatrix, viewSpacePosition), viewSpacePosition.z * projMatrix[2].w);
#else
	return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), viewSpacePosition.z * gl_ProjectionMatrix[2].w);
#endif
}

#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/Vertex_Displacements.vsh"

mat3 CalculateTBN(vec3 worldPosition) {
	vec3 tangent  = normalize(at_tangent.xyz);
	vec3 binormal = normalize(-cross(gl_Normal, at_tangent.xyz));
	
	#if defined gbuffers_water || defined gbuffers_textured
		tangent  += CalculateVertexDisplacements(worldPosition +  tangent) - worldDisplacement;
		binormal += CalculateVertexDisplacements(worldPosition + binormal) - worldDisplacement;
	#endif
	
	tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix *  tangent);
	binormal =           mat3(gbufferModelViewInverse) * gl_NormalMatrix * binormal ;
	
	vec3 normal = normalize(cross(-tangent, binormal));
	
	binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

uniform ivec2 atlasSize;

void main() {
	

	materialIDs  = mc_Entity.x;
	
#ifdef HIDE_ENTITIES
//	if (isEntity(materialIDs)) { gl_Position = vec4(-1.0); return; }
#endif
	
	SetupProjection();
	
	color        = abs(mc_Entity.x - 10.5) > 0.6 ? gl_Color.rgb : vec3(1.0);
	texcoord     = gl_MultiTexCoord0.st;
	vertLightmap = GetDefaultLightmap();

	#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
	blocklight = at_midBlock.w;
	#else
	blocklight = vertLightmap.r;
	#endif
	
	vec3 worldSpacePosition = GetWorldSpacePosition();
	
	worldDisplacement = CalculateVertexDisplacements(worldSpacePosition);

	position[1] = worldSpacePosition + worldDisplacement;
	position[0] = position[1] * mat3(gbufferModelViewInverse);
	
	gl_Position = ProjectViewSpace(position[0]);
	
	
	tbnMatrix = CalculateTBN(worldSpacePosition);

	#if defined gbuffers_water || defined gbuffers_textured
		SetupShading();
	#endif

	// thanks to NinjaMike and Null
	vec2 halfSize      = abs(texcoord - mc_midTexCoord.xy);
	vec4 textureBounds = vec4(mc_midTexCoord.xy - halfSize, mc_midTexCoord.xy + halfSize);

	textureResolution = ivec2(((textureBounds.zw - textureBounds.xy) * atlasSize) + vec2(0.5));

}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh



uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;
uniform sampler2D shadowcolor0;
uniform sampler2D colortex10;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 eyePosition;

uniform float nightVision;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 atlasSize;

uniform float wetness;
uniform float near;
uniform float far;



#include "/lib/Settings.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Misc/CalculateFogfactor.glsl"
#include "/lib/Fragment/Masks.fsh"

uniform sampler3D gaux1;

#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/ComputeShadedFragment.fsh"
#include "/lib/Fragment/ComputeWaveNormals.fsh"

float LOD;

#ifdef TERRAIN_PARALLAX
	#define GetTexture(x, y) texture2DLod(x, y, LOD)
#else
	#define GetTexture(x, y) texture2D(x, y)
#endif
	
#ifdef gbuffers_water
	layout (r32ui) uniform uimage2D waterdepth;
	layout (r32ui) uniform uimage2D waternormal;

	#define GetTexture(x, y) texture2D(x, y)
#endif


vec4 GetDiffuse(vec2 coord) {
	return vec4(color.rgb, 1.0) * GetTexture(tex, coord);
}

bool handLight = false;


vec3 getLightDirWorld(vec3 worldPos, float lightmap){
	vec2 grad = vec2(dFdx(lightmap), dFdy(lightmap));

	cfloat epsilon = 0.000000001;

	if(length(grad) < epsilon){
		return vec3(0.0);
	}

	vec3 A = dFdx(worldPos) / grad.x;
	vec3 B = dFdy(worldPos) / grad.y;

	grad += vec2(lessThan(abs(grad), vec2(epsilon))) * epsilon;

	if(isnan(length(A)) && isnan(length(B))){
		return vec3(0.0);
	}

	if(isnan(length(A))){
		return normalize(B);
	}

	if(isnan(length(B))){
		return normalize(A);
	}

	vec3 perp = B - A;

	vec3 ortho = cross(A, B);
	vec3 dir = normalize(cross(perp, ortho));

	return dir;
}

// basically designed by CyanEmber and Balint
float getDirectionalLightingFactor(vec3 faceNormal, vec3 mappedNormal, vec3 worldPos, float lightmap){
	vec3 lightDir = getLightDirWorld(worldPos, lightmap);

	lightDir = normalize(faceNormal * lightmap + lightDir);

	float directionalLighting = dot(normalize((faceNormal * lightmap + lightDir * 2.0)), mappedNormal);
	return clamp01(directionalLighting);
}

#include "/lib/iPBR/iPBR.glsl"


#include "/lib/Fragment/TerrainParallax.fsh"
#include "/lib/Misc/Euclid.glsl"

#if defined gbuffers_water
/* RENDERTARGETS: 0,3,8,13,11 */
#elif defined gbuffers_textured
/* RENDERTARGETS: 0,3,8,13 */
#else
/* RENDERTARGETS: 1,4,9,10,11 */
#endif

#include "/lib/Exit.glsl"

void main() {


	PBRData PBR;
	PBR = getRawPBRData(texcoord);
	injectIPBR(PBR, materialIDs);
	

	#ifdef gbuffers_hand
	if(heldBlockLightValue + heldBlockLightValue2 > 0){
		handLight = true;
	}
	#endif

	if (CalculateFogFactor(position[0]) >= 1.0)
		{ discard; }
	
	vec2  coord       		= ComputeParallaxCoordinate(texcoord, position[1]);
	vec4  diffuse     		= GetDiffuse(coord);

	// so, having full transparent rain messes with fog, instead we dither it. Thanks joyouscreeper for this mildly criminal idea which works better than could be hoped
	#ifdef gbuffers_weather
	#ifndef RAIN
		discard;
	#endif

	// float rainNoise = blueNoise(gl_FragCoord.xy + vec2(pow2(frameCounter % 64)));
	// float rainNoise = bayer8(gl_FragCoord.xy + vec2(pow2(frameCounter % 8)));
	float rainNoise = ign(floor(gl_FragCoord.xy), frameCounter);
	diffuse = vec4(0.9, 0.9, 1.0, step(0.5, rainNoise) * 0.5 * diffuse.a);

	#endif

	 if (diffuse.a < 0.1) { discard; }
	

	vec3	faceNormal			= tbnMatrix * vec3(0.0, 0.0, 1.0);
	vec3  normal      		= tbnMatrix * PBR.normal;
	#ifdef DIRECTIONAL_LIGHTING
		float directionalLightingFactor = getDirectionalLightingFactor(faceNormal, normal, position[1], vertLightmap.r);
	#else
		float directionalLightingFactor = 1.0;
	#endif
	
	#ifdef gbuffers_hand
	directionalLightingFactor = 1.0;
	#endif

	#ifdef gbuffers_spidereyes
		PBR.emission = 1.0;
	#endif

	

	#if defined gbuffers_water || defined gbuffers_textured
		Mask mask = EmptyMask;

		

		#ifdef gbuffers_textured
		PBR.perceptualSmoothness = 0.0;
		PBR.baseReflectance = 0.0;
		directionalLightingFactor = 1.0;
		#endif

		#ifdef gbuffers_water
		

		if (materialIDs == IPBR_WATER) {
			normal      = tbnMatrix * ComputeWaveNormals(position[1], tbnMatrix[2]);

			#ifdef WATER_BEHIND_TRANSLUCENTS
				uint normalInt = floatBitsToUint(EncodeNormal(normal, 11));
				float depth = gl_FragCoord.z;
				uint depthInt = floatBitsToUint(depth);
				uint oldDepth = imageAtomicMin(waterdepth, ivec2(floor(gl_FragCoord.xy)), depthInt);	

				if (oldDepth > depthInt){ // we wrote the new depth, so write the normal
					imageStore(waternormal, ivec2(floor(gl_FragCoord.xy)), uvec4(normalInt, uvec3(0)));
				}
			#endif

			
			diffuse     = vec4(0.215, 0.356, 0.533, 0.75);
			mask.water  = 1.0;
		}
		#endif


		
		
		vec3 sunlight = vec3(ComputeSunlight(position[1], normal * mat3(gbufferModelViewInverse), tbnMatrix[2], 1.0, PBR.SSS));
		vec3 composite = ComputeShadedFragment(powf(diffuse.rgb, 2.2), mask, vertLightmap.r * directionalLightingFactor, vertLightmap.g, vec4(0.0, 0.0, 0.0, 1.0), normal * mat3(gbufferModelViewInverse), PBR.emission, position, PBR.materialAO, PBR.SSS, tbnMatrix[2], texture(colortex10, texcoord).rgb);
		gl_FragData[3] = vec4(sunlight, 1.0);

		vec2 encode;
		encode.x = Encode4x8F(vec4(directionalLightingFactor, vertLightmap.g, mask.water, 0.1));
		encode.y = EncodeNormal(normal, 11.0);
		
		#ifdef gbuffers_water
		if (materialIDs == IPBR_WATER) {
			composite *= 0.0;
			diffuse.a = 0.0;	
		}
		#endif
		
		gl_FragData[0] = vec4(encode, 0.0, 1.0);
		gl_FragData[1] = vec4(composite, diffuse.a);
		gl_FragData[2] = vec4(PBR.perceptualSmoothness, PBR.baseReflectance, 0.0, 1.0);
		vec3 blockLightColor = vec3(0.0);

		if(IPBR_EMITS_LIGHT(materialIDs)){
			blockLightColor = texture(tex, texcoord).rgb * clamp01(PBR.emission);
		}

		
		#ifndef gbuffers_textured
		if(PBR.emission == 0.0){
			gl_FragData[4] = vec4(0);
		} else {
			gl_FragData[4] = vec4(blockLightColor, 1.0);
		}
		#endif
	#else


		diffuse.rgb = mix(diffuse.rgb, diffuse.rgb * (((1.0 - PBR.porosity) / 2) + 0.5), wetness);
		
		float encodedMaterialIDs = EncodeMaterialIDs(0.0, vec4(0.0, 0.0, 0.0, 0.0));
		
		gl_FragData[0] = vec4(diffuse.rgb, 1.0);
		gl_FragData[1] = vec4(
			Encode4x8F(vec4(
				encodedMaterialIDs, 
				directionalLightingFactor, 
				vertLightmap.rg
			)), 

			EncodeNormal(normal, 11.0), 

			Encode4x8F(vec4(
				PBR.materialAO,
				PBR.SSS,
				0.0,
				0.0
			)), 

			#if defined gbuffers_terrain
			EncodeNormal(tbnMatrix[2], 16.0)
			#else
			1.0
			#endif
		);
		gl_FragData[2] = vec4(PBR.perceptualSmoothness, PBR.baseReflectance, PBR.emission, 1.0);

		vec3 blockLightColor = vec3(0.0);
		if(IPBR_EMITS_LIGHT(materialIDs) || handLight){
			blockLightColor = texture(tex, texcoord).rgb * clamp01(PBR.emission);
		}

		if(materialIDs == IPBR_TORCH){
			blockLightColor = vec3(0.5, 0.2, 0.05) * 4.0 * PBR.emission;
		}

		if(PBR.emission == 0.0){
			gl_FragData[4] = vec4(0.0);
		} else {
			gl_FragData[4] = vec4(blockLightColor, 0.0);
		}
	#endif
	


	exit();
}

#endif
/***********************************************************************/

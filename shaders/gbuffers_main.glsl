#include "/lib/Syntax.glsl"


varying vec3 color;
varying vec2 texcoord;
varying vec2 vertLightmap;
varying flat ivec2 textureResolution;

varying mat3 tbnMatrix;

varying mat2x3 position;

varying vec3 worldDisplacement;

flat varying float materialIDs;



#include "/lib/Uniform/Shading_Variables.glsl"


/***********************************************************************/
#if defined vsh

attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec2 mc_midTexCoord;

uniform float rainStrength;
uniform float thunderStrength;

uniform sampler2D lightmap;

uniform mat4 gbufferModelViewInverse;

uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform float far;



#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"


vec2 GetDefaultLightmap() {
	vec2 lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	return clamp01(lightmapCoord / vec2(0.8745, 0.9373)).rg;
}

#include "/block.properties"

vec3 GetWorldSpacePosition() {
	vec3 position = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
	
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
	
	tangent  += CalculateVertexDisplacements(worldPosition +  tangent) - worldDisplacement;
	binormal += CalculateVertexDisplacements(worldPosition + binormal) - worldDisplacement;
	
	tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix *  tangent);
	binormal =           mat3(gbufferModelViewInverse) * gl_NormalMatrix * binormal ;
	
	vec3 normal = normalize(cross(-tangent, binormal));
	
	binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

uniform ivec2 atlasSize;

void main() {
	materialIDs  = BackPortID(int(mc_Entity.x));
	
#ifdef HIDE_ENTITIES
//	if (isEntity(materialIDs)) { gl_Position = vec4(-1.0); return; }
#endif
	
	SetupProjection();
	
	color        = abs(mc_Entity.x - 10.5) > 0.6 ? gl_Color.rgb : vec3(1.0);
	texcoord     = gl_MultiTexCoord0.st;
	vertLightmap = GetDefaultLightmap();
	
	show(int(mc_Entity.x) == 9)
	vec3 worldSpacePosition = GetWorldSpacePosition();
	
	worldDisplacement = CalculateVertexDisplacements(worldSpacePosition);
	
	position[1] = worldSpacePosition + worldDisplacement;
	position[0] = position[1] * mat3(gbufferModelViewInverse);
	
	gl_Position = ProjectViewSpace(position[0]);
	
	
	tbnMatrix = CalculateTBN(worldSpacePosition);

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

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform float nightVision;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform ivec2 atlasSize;

uniform float wetness;
uniform float far;

#include "/lib/Settings.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Misc/CalculateFogfactor.glsl"
#include "/lib/Fragment/Masks.fsh"

float LOD;

#ifdef TERRAIN_PARALLAX
	#define GetTexture(x, y) texture2DLod(x, y, LOD)
#else
	#define GetTexture(x, y) texture2D(x, y)
#endif

vec4 GetDiffuse(vec2 coord) {
	return vec4(color.rgb, 1.0) * GetTexture(tex, coord);
}

vec3 GetNormal(vec2 coord) {
	vec3 normal = vec3(0.0, 0.0, 1.0);
	
#ifdef NORMAL_MAPS
	normal = GetTexture(normals, coord).rgb;
	normal = normal * 2.0 - 1.0;
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));
#endif
	
	return tbnMatrix * normal;
}

float getMaterialAO(vec2 coord){
	#ifndef NORMAL_MAPS
	return 0;
	#endif

	return GetTexture(normals, coord).z;
}

vec3 GetTangentNormal() {
#ifdef NORMAL_MAPS
	vec3 normal = texture2D(normals, texcoord).rgb;
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));
	return normal;
#endif
	
	return vec3(0.5, 0.5, 1.0);
}

float GetSpecularity(vec2 coord) {
	float specularity = 0.0;
	
#ifdef SPECULARITY_MAPS
	float smoothness = GetTexture(specular, coord).r;

	float baseReflectance = GetTexture(specular, coord).g * (229 / 255);

	specularity = pow(smoothness, 2) * baseReflectance;
#endif
	
	return clamp01(specularity + wetness);
}

float getPerceptualSmoothness(vec2 coord){
	#ifdef SPECULARITY_MAPS
	return GetTexture(specular, coord).r;
	#endif
	return 0;
}

float getBaseReflectance(vec2 coord){
	#ifdef SPECULARITY_MAPS
	return GetTexture(specular, coord).g;
	#endif
	return 0;
}

float getPorosity(vec2 coord, bool isDielectric){
	#ifndef SPECULARITY_MAPS
		return 0;
	#endif
	if(!isDielectric){
		return 0;
	}
	float porosity = GetTexture(specular, coord).b;

	if (porosity > 0.25){ // subsurface scattering range
		return 0;
	}
	
	return porosity * 4;
}

float getEmission(vec2 coord){
	#ifdef EMISSION
	float emission = GetTexture(specular, coord).a;
	if (emission == 1.0) {
		return 0;
	}
	return emission;
	#endif
	return 0;
}


#include "/lib/Fragment/TerrainParallax.fsh"
#include "/lib/Misc/Euclid.glsl"

/* DRAWBUFFERS:149 */

#include "/lib/Exit.glsl"

void main() {
	if (CalculateFogFactor(position[0]) >= 1.0)
		{ discard; }
	
	vec2  coord       		= ComputeParallaxCoordinate(texcoord, position[1]);
	vec4  diffuse     		= GetDiffuse(coord); if (diffuse.a < 0.1) { discard; }
	vec3  normal      		= GetNormal(coord);
	float specularity 		= GetSpecularity(coord);
	float perceptualSmoothness				= getPerceptualSmoothness(coord);
	float baseReflectance = getBaseReflectance(coord);
	float emission 				= getEmission(coord);
	float porosity				= getPorosity(coord, (baseReflectance <= 1.0));
	float materialAO			= getMaterialAO(coord);

	if (porosity > 0){
		baseReflectance = mix(baseReflectance, 0.1 * porosity, wetness * vertLightmap.g);
		perceptualSmoothness = mix(perceptualSmoothness, (1.0 - porosity), wetness * vertLightmap.g);
	}

	diffuse.rgb = mix(diffuse.rgb, diffuse.rgb * (((1.0 - porosity) / 2) + 0.5), wetness);
	
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, vec4(0.0, 0.0, 0.0, 0.0));
	
	gl_FragData[0] = vec4(diffuse.rgb, 1.0);
	gl_FragData[1] = vec4(Encode4x8F(vec4(encodedMaterialIDs, specularity, vertLightmap.rg)), EncodeNormal(normal, 11.0), materialAO, 1.0);
	gl_FragData[2] = vec4(perceptualSmoothness, baseReflectance, emission, 1.0);

	exit();
}

#endif
/***********************************************************************/

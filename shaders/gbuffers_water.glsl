#include "/lib/Syntax.glsl"


varying vec3 color;
varying vec2 texcoord;
varying vec2 vertLightmap;

varying mat3 tbnMatrix;

varying mat2x3 position;

varying vec3 worldDisplacement;

flat varying float materialIDs;

#include "/lib/Uniform/Shading_Variables.glsl"


/***********************************************************************/
#if defined vsh

attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;

uniform float rainStrength;

uniform sampler2D lightmap;

uniform mat4 gbufferModelViewInverse;

uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform float far;
uniform float wetness;
uniform float thunderStrength;


#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"

#if defined gbuffers_water
uniform sampler3D gaux1;

#include "/UserProgram/centerDepthSmooth.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.vsh"
#include "/lib/Fragment/PrecomputedSky.glsl"
#include "/lib/Vertex/Shading_Setup.vsh"
#endif


vec2 GetDefaultLightmap() {
	vec2 lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	return clamp01(lightmapCoord / vec2(0.8745, 0.9373)).rg;
}

#include "/block.properties"

vec3 GetWorldSpacePosition() {
	vec3 position = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
	
#if  defined gbuffers_water
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
	
	tangent  += CalculateVertexDisplacements(worldPosition +  tangent) - worldDisplacement;
	binormal += CalculateVertexDisplacements(worldPosition + binormal) - worldDisplacement;
	
	tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix *  tangent);
	binormal =           mat3(gbufferModelViewInverse) * gl_NormalMatrix * binormal ;
	
	vec3 normal = normalize(cross(-tangent, binormal));
	
	binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

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
	
	
	SetupShading();
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
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform float nightVision;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform float viewHeight;

uniform ivec2 atlasSize;

uniform float wetness;
uniform float far;
uniform float rainStrength;


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


#include "/lib/Fragment/TerrainParallax.fsh"
#include "/lib/Misc/Euclid.glsl"


/* DRAWBUFFERS:038 */

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
	
	specularity = clamp(specularity, 0.0, 1.0 - 1.0 / 255.0);
	
	Mask mask = EmptyMask;
	
	if (materialIDs == 4.0) {
		if (!gl_FrontFacing) discard;
		
		diffuse     = vec4(0.215, 0.356, 0.533, 0.75);
		normal      = tbnMatrix * ComputeWaveNormals(position[1], tbnMatrix[2]);
		specularity = 1.0;
		perceptualSmoothness = 1;
		baseReflectance = 0.02;
		mask.water  = 1.0;
	}
	
	vec3 composite = ComputeShadedFragment(powf(diffuse.rgb, 2.2), mask, vertLightmap.r, vertLightmap.g, vec4(0.0, 0.0, 0.0, 1.0), normal * mat3(gbufferModelViewInverse), 0, position);
	
	vec2 encode;
	encode.x = Encode4x8F(vec4(specularity, vertLightmap.g, mask.water, 0.1));
	encode.y = EncodeNormal(normal, 11.0);
	
	if (materialIDs == 4.0) {
		composite *= 0.0;
		diffuse.a = 0.0;
	}
	
	gl_FragData[0] = vec4(encode, 0.0, 1.0);
	gl_FragData[1] = vec4(composite, diffuse.a);
	gl_FragData[2] = vec4(perceptualSmoothness, baseReflectance, 0.0, 1.0);

	exit();
}

#endif
/***********************************************************************/

#include "/lib/Syntax.glsl"

#include "/lib/Settings.glsl"

#include "/lib/iPBR/IDs.glsl"
#include "/lib/iPBR/Groups.glsl"


varying vec4 color;
varying vec2 texcoord;
varying vec2 vertLightmap;

flat varying vec3 vertNormal;
varying float materialIDs;

varying vec3 position;


/***********************************************************************/
#if defined vsh

#if defined FLOODFILL_BLOCKLIGHT && defined IRIS_FEATURE_CUSTOM_IMAGES
layout (rgba16f) uniform image3D lightvoxel;
layout (rgba16f) uniform image3D lightvoxelf;
#endif

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
attribute vec4 at_tangent;
attribute vec3 at_midBlock;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform int entityId;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;

uniform float thunderStrength;



#include "/lib/Utility.glsl"

#include "/lib/Voxel/VoxelPosition.glsl"
#include "/lib/iPBR/lightColors.glsl"

#include "/UserProgram/centerDepthSmooth.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"
#include "/lib/Uniform/Shadow_View_Matrix.vsh"

bool EVEN_FRAME = frameCounter % 2 == 0;

vec2 GetDefaultLightmap() {
	vec2 lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	return clamp01((lightmapCoord * pow2(1.031)) - 0.032).rg;
}

vec3 GetWorldSpacePositionShadow() {
	return transMAD(shadowModelViewInverse, transMAD(gl_ModelViewMatrix, gl_Vertex.xyz));
}

#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/Vertex_Displacements.vsh"

#include "/lib/Misc/ShadowBias.glsl"

vec4 ProjectShadowMap(vec4 position) {
	position = vec4(projMAD(shadowProjection, transMAD(shadowViewMatrix, position.xyz)), position.z * shadowProjection[2].w + shadowProjection[3].w);
	
	float biasCoeff = GetShadowBias(position.xy);
	
	position.xy /= biasCoeff;
	
	float acne  = 25.0 * pow4(clamp01(1.0 - vertNormal.z));
	      acne += 0.5 + pow2(biasCoeff) * 8.0;
	
	position.z += acne / shadowMapResolution;
	
	position.z /= zShrink; // Shrink the domain of the z-buffer. This counteracts the noticable issue where far terrain would not have shadows cast, especially when the sun was near the horizon
	
	return position;
}

vec2 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return (diagonal2(projMatrix) * viewSpacePosition.xy + projMatrix[3].xy) / -viewSpacePosition.z;
}

vec3 ViewSpaceToScreenSpace3(vec3 viewSpacePosition) {
	return (diagonal3(projMatrix) * viewSpacePosition.xyz + projMatrix[3].xyz) / -viewSpacePosition.z;
}

bool CullVertex(vec3 wPos) {
#ifdef GI_ENABLED
	return false;
#endif
	
	vec3 vRay = transpose(mat3(shadowViewMatrix))[2] * mat3(gbufferModelViewInverse); // view space light vector
	
	vec3 vPos = wPos * mat3(gbufferModelViewInverse);
	
	vPos.z -= 4.0;
	
	bool onscreen = all(lessThan(abs(ViewSpaceToScreenSpace(vPos)), vec2(1.0))) && vPos.z < 0.0;
	
	// c = distances to intersection with 4 frustum sides, vec4(xy = -1.0, xy = 1.0)
	vec4 c =  vec4(diagonal2(projMatrix) * vPos.xy + projMatrix[3].xy, diagonal2(projMatrix) * vRay.xy);
	     c = -vec4((c.xy - vPos.z) / (c.zw - vRay.z), (c.xy + vPos.z) / (c.zw + vRay.z)); // Solve for (M*(vPos + ray*c) + A) / (vPos.z + ray.z*c) = +-1.0
	
	vec3 b1 = vPos + vRay * c.x;
	vec3 b2 = vPos + vRay * c.y;
	vec3 b3 = vPos + vRay * c.z;
	vec3 b4 = vPos + vRay * c.w;
	
	vec4 otherCoord = vec4( // vec4(y coord of x = -1.0 intersection,   x coord of y = -1.0,   y coord of x = 1.0,   x coord of y = 1.0)
		(projMatrix[1].y * b1.y + projMatrix[3].y) / -b1.z,
		(projMatrix[0].x * b2.x + projMatrix[3].x) / -b2.z,
		(projMatrix[1].y * b3.y + projMatrix[3].y) / -b3.z,
		(projMatrix[0].x * b4.x + projMatrix[3].x) / -b4.z);
	
	vec3 yDot = transpose(mat3(gbufferModelViewInverse))[1];
	
	vec4 w = vec4(dot(b1, yDot), dot(b2, yDot), dot(b3, yDot), dot(b4, yDot)); // World space y intersection points
	
	bvec4 yBounded   = lessThan(abs(w + cameraPosition.y - 128.0), vec4(128.0)); // Intersection happens within y[0.0, 256.0]
	bvec4 inFrustum  = lessThan(abs(otherCoord), vec4(1.0)); // Example: check the y coordinate of the x-hits to make sure the intersection happens within the 2 adjacent frustum edges
	bvec4 correctDir = and(lessThan(vec4(b1.z, b2.z, b3.z, b4.z), vec4(0.0)), lessThan(c, vec4(0.0)));
	
	bool castscreen = any(and(and(inFrustum, correctDir), yBounded));
	
	return !(onscreen || castscreen);
}

void main() {
	#ifndef SHADOWS
		gl_Position = ftransform();
		return;
	#endif
	
	materialIDs  = mc_Entity.x;
	
#ifdef HIDE_ENTITIES
//	if (mc_Entity.x < 0.5) { gl_Position = vec4(-1.0); return; }
#endif
	
	CalculateShadowView();
	SetupProjection();
	
	color        = gl_Color;
	texcoord     = gl_MultiTexCoord0.st;
	vertLightmap = GetDefaultLightmap();
	
	vertNormal   = normalize(mat3(shadowViewMatrix) * gl_Normal);
	
	
	position  = GetWorldSpacePositionShadow();
	vec3 previousPosition = position + (previousCameraPosition - cameraPosition);
	     position += CalculateVertexDisplacements(position);

	

	#if defined FLOODFILL_BLOCKLIGHT && defined IRIS_FEATURE_CUSTOM_IMAGES
	if(IPBR_EMITS_LIGHT(materialIDs)){
		ivec3 voxelPos = mapPreviousVoxelPos(previousPosition + at_midBlock * rcp(64.0));

		if(isWithinVoxelBounds(voxelPos)) {
			vec3 lightColor = getLightColor(int(materialIDs));

			if(EVEN_FRAME){
				imageStore(lightvoxelf, voxelPos, vec4(lightColor, 1.0));
			} else {
				imageStore(lightvoxel, voxelPos, vec4(lightColor, 1.0));
			}
		}
	}
	#endif


	gl_Position = ProjectShadowMap(position.xyzz);
	
	// if (CullVertex(position)) { gl_Position.z += 100000.0; return; }
	
	
	color.rgb *= clamp01(vertNormal.z);
	
	if (entityId == 1) {
	#ifndef PLAYER_SHADOW
		color.a = 0.0;
	#elif !defined PLAYER_GI_BOUNCE
		color.rgb = vec3(0.0);
	#endif
	}
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

uniform sampler2D gtexture;
uniform vec3 fogColor;
uniform ivec2 eyeBrightnessSmooth;
uniform sampler2D noisetex;
uniform float far;
uniform float near;
uniform vec3 cameraPosition;

#include "/lib/Utility.glsl"
#include "/lib/Fragment/ComputeWaveNormals.fsh"

#define pow2(x) x*x

void main() {
	#ifndef SHADOWS
	discard;
	#endif

	vec4 diffuse = color * texture2D(gtexture, texcoord);

	if (materialIDs == IPBR_WATER) {
		diffuse = vec4(0.015, 0.04, 0.098, 0.5);
		#ifdef WATER_CAUSTICS
			SetupWaveFBM();
			float height = GetWaves(position.xz + cameraPosition.xz);
			height *= height * height * height;
			diffuse.a = (1.0 - height);
		#endif
	}
	
	gl_FragData[0] = diffuse;
	gl_FragData[1] = vec4(vertNormal.xy * 0.5 + 0.5, 0.0, 1.0);
}

#endif
/***********************************************************************/

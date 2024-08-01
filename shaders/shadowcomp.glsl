#include "/lib/Syntax.glsl"
#include "/lib/Settings.glsl"

/***********************************************************************/
#if defined csh
  layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
  const ivec3 workGroups = ivec3(32, 32, 32); // 32*8 = 256

  #if defined FLOODFILL_BLOCKLIGHT && defined IRIS_FEATURE_CUSTOM_IMAGES
  uniform vec3 cameraPosition;
  uniform vec3 previousCameraPosition;
  uniform int frameCounter;
  uniform int heldItemId;
  uniform int heldItemId2;
  uniform int heldBlockLightValue;
  uniform int heldBlockLightValue2;

  #include "/lib/Voxel/VoxelPosition.glsl"
  #include "/lib/iPBR/lightColors.glsl"

  layout (rgba16f) uniform image3D lightvoxel;
  layout (rgba16f) uniform image3D lightvoxelf;

  bool EVEN_FRAME = frameCounter % 2 == 0;

  

  vec3 getColor(ivec3 voxelPos){
    #ifdef HANDLIGHT
    if(voxelPos == ivec3(VOXEL_MAP_SIZE / 2)){
      vec3 handColor = vec3(0.0);
      if(heldBlockLightValue > 0){
        handColor += getLightColor(heldItemId);
      }
      if(heldBlockLightValue2 > 0){
        handColor += getLightColor(heldItemId2);
        handColor /= 2;
      }
      if(handColor != vec3(0.0)){
        return handColor;
      }
    }
    #endif

    if(EVEN_FRAME){
      return imageLoad(lightvoxelf, voxelPos).rgb;
    } else {
      return imageLoad(lightvoxel, voxelPos).rgb;
    }
  }
  #endif

  void main(){
    #if defined FLOODFILL_BLOCKLIGHT && defined IRIS_FEATURE_CUSTOM_IMAGES
    ivec3 pos = ivec3(gl_GlobalInvocationID); // position in the voxel map we are working with
    ivec3 previousPos = pos - getPreviousVoxelOffset();

    const ivec3[6] sampleOffsets = ivec3[6](
      ivec3( 1,  0,  0),
      ivec3( 0,  1,  0),
      ivec3( 0,  0,  1),
      ivec3(-1,  0,  0),
      ivec3( 0, -1,  0),
      ivec3( 0,  0, -1)
    );

    vec3 color = vec3(0.0);
    
    for(int i = 0; i < 6; i++){
      ivec3 offsetPos = previousPos + sampleOffsets[i];
      if(isWithinVoxelBounds(offsetPos)){
        color += getColor(offsetPos);
      }
    }

    color /= 6;

    color *= 0.97; // ever so slight falloff to prevent positive feedback

    if(length(color) < 0.001){
      color = vec3(0.0);
    }

    //color = getColor(previousPos);

    if(EVEN_FRAME){
      imageStore(lightvoxel, pos, vec4(color.rgb, 1.0));
    } else {
      imageStore(lightvoxelf, pos, vec4(color.rgb, 1.0));
    }
    
    #endif
  }

#endif
/***********************************************************************/

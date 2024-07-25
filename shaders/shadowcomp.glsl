#include "/lib/Syntax.glsl"
#include "/lib/Settings.glsl"

/***********************************************************************/
#if defined csh
  uniform vec3 cameraPosition;
  uniform int heldItemId;
  uniform int heldItemId2;

  #include "/lib/Voxel/VoxelPosition.glsl"
  #include "/lib/iPBR/lightColors.glsl"

  layout (rgba8) uniform image3D lightvoxel;
  layout (rgba8) uniform image3D lightvoxelf;

  #ifdef SHADOWCOMP_EVEN
    #define READ_IMAGE lightvoxel
    #define WRITE_IMAGE lightvoxelf
  #else
    #define READ_IMAGE lightvoxelf
    #define WRITE_IMAGE lightvoxel
  #endif

  layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
  const ivec3 workGroups = ivec3(32, 32, 32); // 32*8 = 256

  void main(){
    ivec3 pos = ivec3(gl_GlobalInvocationID); // position in the voxel map we are working with

    const ivec3[6] sampleOffsets = ivec3[6](
      ivec3( 1,  0,  0),
      ivec3( 0,  1,  0),
      ivec3( 0,  0,  1),
      ivec3(-1,  0,  0),
      ivec3( 0, -1,  0),
      ivec3( 0,  0, -1)
    );

    int sampleCount = 1;

    vec3 colorSum = imageLoad(READ_IMAGE, pos).rgb;
    
    #if defined shadowcomp0 && defined HANDLIGHT
    if(pos == mapVoxelPos(vec3(0, 0, 0))){
      colorSum += getLightColor(heldItemId);
      colorSum += getLightColor(heldItemId2);
      colorSum = normalize(colorSum);
    }
    #endif
    
    for(int i = 0; i < 6; i++){
      ivec3 offsetPos = pos + sampleOffsets[i];
      vec3 colorSample = imageLoad(READ_IMAGE, offsetPos).rgb;
      if(length(colorSample) > 0.01){
        colorSum += colorSample;
        sampleCount++;
      }
    }

    vec3 color = colorSum / float(sampleCount);

    #ifdef shadowcomp15
      if(color == vec3(0.0)){
        color = torchColor;
      }
    #endif
    
    imageStore(WRITE_IMAGE, pos, vec4(normalize(color), 1.0));
  }

#endif
/***********************************************************************/

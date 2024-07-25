// this must also be the image resolution on all 3 axes in shaders.properties AND there's some stuff in shadowcomp you'd need to change as well
// but honestly, just don't change it
#define VOXEL_MAP_SIZE 256

// takes in a player space position and returns a position in the voxel map
ivec3 mapVoxelPos(vec3 playerPos){
  return ivec3(playerPos + fract(cameraPosition) + ivec3(VOXEL_MAP_SIZE / 2));
}

// for sampling the voxel texture as a sampler3D so we get interpolation
vec3 mapVoxelPosInterp(vec3 playerPos){
  return (playerPos + fract(cameraPosition) + VOXEL_MAP_SIZE / 2) / VOXEL_MAP_SIZE;
}
#include "/lib/Misc/Euclid.glsl"

const float[3] portals = float[3](
  2304.5,
  3808.5,
  5376.5
);

#ifdef vsh
void doPortals(inout vec3 position, vec3 midblock){
#else
void doPortals(vec3 position, vec3 midblock){
#endif


  for(int i = 0; i < portals.length(); i++){
    doPortal(portals[i], position, midblock);
  }
}

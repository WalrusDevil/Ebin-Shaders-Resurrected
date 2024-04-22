#include "/lib/GLSL_Version.glsl"
#define gbuffers_water
#define vsh
#define world1
#define ShaderStage -2


uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform float sunAngle;


#include "/gbuffers_water.glsl"

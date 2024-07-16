#ifndef IPBR
#define IPBR

#include "/lib/iPBR/IDs.glsl"
#include "/lib/iPBR/Groups.glsl"

struct PBRData {
  vec4 albedo;
  float perceptualSmoothness;
  float baseReflectance;
  float porosity;
  float SSS;
  float emission;

  float materialAO;
  float height;
  vec3 normal;
};

float generateEmission(vec3 albedo, float lumaThreshold, float satThreshold){
  vec3 hsvcol = hsv(albedo);
  float luma = hsvcol.b;
	float sat = hsvcol.g;

  if(luma < lumaThreshold){
    return smoothstep(satThreshold, 1.0, sat);
  }

  return luma;
}

#ifdef gbuffers_main
  PBRData getRawPBRData(vec2 coord, int ID){
    vec4 specularData = texture(specular, coord);
    vec4 normalData = texture(normals, coord);

    PBRData data;

    data.albedo = texture(gtexture, coord);

    data.perceptualSmoothness = specularData.r;
    data.baseReflectance = specularData.g;

    float porositySSS = specularData.b;
    data.porosity = porositySSS <= 0.25 ? porositySSS * 4.0 : 0.0;
    data.SSS = porositySSS > 0.25 ? (porositySSS - 0.25) * (4.0/3.0);

    data.emission = specularData.a != 1.0 ? specularData.a : 0.0;

    data.materialAO = normalData.b;
    data.height = normalData.a * 0.75 + 0.25;
    data.normal.xy = normalData.xy;
    data.normal.z = sqrt(1.0 - dot(data.normal.xy, data.normal.xy));
  }

  PBRData injectIPBR(PBRData rawData, int ID){
    switch(ID){
      case IPBR_WATER:
        data.perceptualSmoothness = 1.0;
        data.baseReflectance = 0.02;
        data.normal = tbnMatrix * ComputeWaveNormals(position[1], tbnMatrix[2]);
        break;

      case IPBR_NETHER_PORTAL:
        data.perceptualSmoothness = 0.9;
        data.baseReflectance = 0.02;
        data.emission = 0.7;

      case IPBR_EMITS_LIGHT:
        data.emission = generateEmission(data.albedo, 0.8, 0.6);
      
    }
  }
#endif

#endif
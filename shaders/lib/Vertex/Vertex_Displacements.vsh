vec3 CalculateVertexDisplacements(vec3 worldSpacePosition) {
	vec3 worldPosition = worldSpacePosition + cameraPos;
	
#if !defined gbuffers_shadow && !defined gbuffers_basic
	worldPosition += previousCameraPosition - cameraPosition;
#endif
	
	vec3 displacement = vec3(0.0);
	
#if defined gbuffers_terrain || defined gbuffers_water || defined gbuffers_shadow
	if      (materialIDs == 2.0)
		{ displacement += GetWavingLeaves(worldPosition); }
	
	else if (materialIDs == 4.0)
		{ displacement += GetWavingWater(worldPosition); }
#endif
	
#if !defined gbuffers_hand
	displacement += TerrainDeformation(worldSpacePosition) - worldSpacePosition;
#endif
	
	return displacement;
}

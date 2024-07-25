#ifndef IPBR_GROUPS
#define IPBR_GROUPS

bool IPBR_EMITS_LIGHT(float ID){
	return 
    (ID >= 1000 && ID < 2000);
}

bool IPBR_IS_FOLIAGE(float ID){
  return
    (ID >= 2000 && ID < 3000);
}

bool IPBR_IS_TALL_GRASS(float ID){
  return
    (ID >= 2008 && ID <= 2009);
}

bool IPBR_IS_FROGLIGHT(float ID){
  return
    (ID >= 1026 && ID <= 1028);
}

bool IPBR_IS_COPPER(float ID){
  return ID == IPBR_COPPER || ID == IPBR_COPPER_BULB_LIT;
}

#endif
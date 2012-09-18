// Don't let the script be included more than once.
#if defined _helper_pillslocation
  #endinput
#endif
#define _helper_pillslocation
static bool:ValidatePillSpawn(Float:x1, Float:x2, Float:y1, Float:y2, Float:z1, Float:z2)
{
			if (FloatAbs(x1) < FloatAdd(FloatAbs(x2), 50.0) && 
				FloatAbs(x1) > FloatSub(FloatAbs(x2), 50.0) &&
				FloatAbs(y1) < FloatAdd(FloatAbs(y2), 50.0) && 
				FloatAbs(y1) > FloatSub(FloatAbs(y2), 50.0) &&
				FloatAbs(z1) < FloatAdd(FloatAbs(z2), 50.0) && 
				FloatAbs(z1) > FloatSub(FloatAbs(z2), 50.0))
			{
				return true;		
			}
			return false;
}

stock GetPillEntities(map, pills[4])
{
	decl fFirstPills[50][3],fSecondPills[50][3], fThirdPills[50][3], fFourthPills[50][3];
	new first;
	new second;
	new third;
	new fourth;
	new entity = -1;
	decl Float:entityPos[3];
	
	if (map == 101)
	{
		fFirstPills[0] = { 1609.812500 , 863.750000 , 327.218750 };
		fFirstPills[1] = { 2268.750000 , 788.875000 , 172.218750 };
		fFirstPills[2] = { 2107.812500 , 928.687500 , 204.218750 };
		fFirstPills[3] = { 2110.000000 , 602.250000 , 192.218750 };

		fSecondPills[0] = { 1959.406250 , 928.656250 , 202.500000 };
		fSecondPills[1] = { 1641.000000 , 1341.000000 , 191.000000 };
		fSecondPills[2] = { 2267.562500 , 1175.593750 , 219.687500 };
		fSecondPills[3] = { 2255.000000 , 1177.593750 , 166.531250 };

		fThirdPills[0] = { 2267.625000 , 1239.437500 , 55.000000 };
		fThirdPills[1] = { 1894.000000 , 1130.406250 , 100.531250 };
		fThirdPills[2] = { 2074.000000 , 908.000000 , 25.000000 };

		fFourthPills[0] = { 1786.968750 , 2930.968750 , 53.812500 };

		first = GetRandomInt(0,3);
		second = GetRandomInt(0,3);
		third = GetRandomInt(0,2);
		fourth = GetRandomInt(0,0);
	}
	if (map == 102)
	{		
		fFirstPills[0] = { 2891.593750 , 2961.406250 , 52.468750 };

		fSecondPills[0] = { 4003.156250 , 4120.093750 , -475.750000 };
		fSecondPills[1] = { 3676.625000 , 4125.125000 , -476.750000 };
		fSecondPills[2] = { 3666.187500 , 4027.125000 , -510.000000 };
		fSecondPills[3] = { 4041.312500 , 4117.562500 , -475.000000 };

		fThirdPills[0] = { 7301.687500 , 3074.718750 , -278.218750 };

		fFourthPills[0] = { 7782.375000 , 4059.343750 , 32.218750 };
		fFourthPills[1] = { 7653.000000 , 3956.000000 , 67.312500 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,3);
		third = GetRandomInt(0,0);
		fourth = GetRandomInt(0,1);
	}
	if (map == 103)
	{
		fFirstPills[0] = { 10946.000000 , 4632.000000 , 50.218750 };
		
		fSecondPills[0] = { 10782.000000 , 7083.000000 , 212.312500 };

		fThirdPills[0] = { 10856.000000 , 7268.656250 , 165.218750 };
		fThirdPills[1] = { 10773.781250 , 7720.718750 , 194.000000 };
		fThirdPills[2] = { 10712.875000 , 7975.000000 , 193.343750 };
		fThirdPills[3] = { 10794.187500 , 7831.375000 , 195.000000 };
		fThirdPills[4] = { 10713.687500 , 8204.312500 , 195.000000 };
		fThirdPills[5] = { 10858.375000 , 8197.625000 , 193.218750 };

		fFourthPills[0] = { 14234.593750 , 8130.750000 , -242.437500 };
		fFourthPills[1] = { 14268.000000 , 7908.000000 , -255.625000 };
		fFourthPills[2] = { 13885.000000 , 7872.500000 , -255.625000 };
		fFourthPills[3] = { 13731.593750 , 7886.031250 , -254.000000 };
		fFourthPills[4] = { 13712.000000 , 8080.000000 , -255.750000 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,0);
		third = GetRandomInt(0,5);
		fourth = GetRandomInt(0,4);
	}
	if (map == 104)
	{
		fFirstPills[0] = { 12202.593750 , 11952.500000 , 50.218750 };
		fFirstPills[1] = { 12095.093750 , 12081.781250 , 50.000000 };
		fFirstPills[2] = { 11949.500000 , 12632.593750 , 50.218750 };
		fFirstPills[3] = { 12515.000000 , 12893.875000 , 51.437500 };
		fFirstPills[4] = { 12643.000000 , 12711.000000 , 50.218750 };
		fFirstPills[5] = { 12893.000000 , 13053.093750 , 50.218750 };
		fFirstPills[6] = { 12887.000000 , 13438.000000 , 51.000000 };

		fSecondPills[0] = { 12132.375000 , 13465.875000 , 185.218750 };
		fSecondPills[1] = { 11932.000000 , 12726.187500 , 192.000000 };
		fSecondPills[2] = { 11947.687500 , 12662.187500 , 199.218750 };
		fSecondPills[3] = { 11943.281250 , 12794.000000 , 164.437500 };
		fSecondPills[4] = { 11944.000000 , 12839.187500 , 192.000000 };
		fSecondPills[5] = { 12141.000000 , 12504.593750 , 192.218750 };
		fSecondPills[6] = { 12205.093750 , 12488.281250 , 194.000000 };
		fSecondPills[7] = { 12245.000000 , 12496.593750 , 192.218750 };
		fSecondPills[8] = { 12116.000000 , 12332.000000 , 190.000000 };
		fSecondPills[9] = { 12245.000000 , 12328.593750 , 188.218750 };
		fSecondPills[10] = { 12390.093750 , 12367.593750 , 188.437500 };
		fSecondPills[11] = { 12823.187500 , 13054.187500 , 208.218750 };
		fSecondPills[12] = { 12829.687500 , 13158.093750 , 184.531250 };
		fSecondPills[13] = { 12836.593750 , 13475.375000 , 185.218750 };

		fThirdPills[0] = { 12040.500000 , 13324.875000 , 323.218750 };
		fThirdPills[1] = { 11943.281250 , 13091.500000 , 323.000000 };
		fThirdPills[2] = { 12108.281250 , 12628.187500 , 323.000000 };
		fThirdPills[3] = { 12068.593750 , 12629.593750 , 322.218750 };
		fThirdPills[4] = { 11946.375000 , 12574.687500 , 324.000000 };
		fThirdPills[5] = { 11942.781250 , 12525.281250 , 322.218750 };
		fThirdPills[6] = { 11965.875000 , 12032.000000 , 322.000000 };
		fThirdPills[7] = { 12017.781250 , 12219.000000 , 320.218750 };
		fThirdPills[8] = { 12034.187500 , 12263.187500 , 322.000000 };

		fFourthPills[0] = { 11943.093750 , 13160.781250 , 458.218750 };
		fFourthPills[1] = { 11943.187500 , 13419.500000 , 458.218750 };
		fFourthPills[2] = { 12292.000000 , 14176.000000 , 462.000000 };
		fFourthPills[3] = { 11967.281250 , 13977.500000 , 459.000000 };
		fFourthPills[4] = { 12816.000000 , 14026.000000 , 462.218750 };
		fFourthPills[5] = { 12691.000000 , 14236.000000 , 455.218750 };
		fFourthPills[6] = { 12200.281250 , 14372.500000 , 459.000000 };
		fFourthPills[7] = { 12849.000000 , 14515.000000 , 461.000000 };
		fFourthPills[8] = { 12016.093750 , 14640.593750 , 460.468750 };
		fFourthPills[9] = { 12205.687500 , 14817.187500 , 459.000000 };
		fFourthPills[10] = { 12552.000000 , 15340.000000 , 461.000000 };
		fFourthPills[11] = { 12736.375000 , 15093.875000 , 460.000000 };
		fFourthPills[12] = { 13562.000000 , 14979.875000 , 457.500000 };
		fFourthPills[13] = { 13527.093750 , 14952.593750 , 447.625000 };
		fFourthPills[14] = { 13741.593750 , 14582.781250 , 459.218750 };
		fFourthPills[15] = { 13737.000000 , 14213.000000 , 425.000000 };
		fFourthPills[16] = { 13494.000000 , 14129.000000 , 459.000000 };
		fFourthPills[17] = { 13444.000000 , 13944.000000 , 461.000000 };
		fFourthPills[18] = { 13348.000000 , 13956.500000 , 461.000000 };
		fFourthPills[19] = { 13168.000000 , 13953.000000 , 458.218750 };

		first = GetRandomInt(0,6);
		second = GetRandomInt(0,13);
		third = GetRandomInt(0,8);
		fourth = GetRandomInt(0,19);
	}
	if (map == 201)
	{				
		fFirstPills[0] = { -11706.281250 , -14605.281250 , -164.875000 };

		fSecondPills[0] = { -11764.000000 , -14623.000000 , -199.000000 };

		fThirdPills[0] = { -12633.593750 , -8988.125000 , -47.750000 };

		fFourthPills[0] = { -13304.687500 , -5903.843750 , -373.468750 };
		fFourthPills[1] = { -12467.000000 , -5274.000000 , -363.250000 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,0);
		third = GetRandomInt(0,0);
		fourth = GetRandomInt(0,1);
	}
	if (map == 202)
	{
		fFirstPills[0] = { -11082.281250 , -8938.437500 , -562.531250 };

		fSecondPills[0] = { -9877.000000 , -7217.000000 , -709.937500 };

		fThirdPills[0] = { -7782.000000 , -8289.000000 , -342.468750 };

		fFourthPills[0] = { -8916.375000 , -7795.593750 , -393.937500 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,0);
		third = GetRandomInt(0,0);
		fourth = GetRandomInt(0,0);
	}
	if (map == 203)
	{
		fFirstPills[0] = { -8329.000000 , -5602.000000 , 6.000000 };

		fSecondPills[0] = { -12561.000000 , -6389.000000 , -25.687500 };
		fSecondPills[1] = { -12581.000000 , -6389.000000 , -26.656250 };
		fSecondPills[2] = { -12767.500000 , -5854.656250 , -63.750000 };
		fSecondPills[3] = { -12768.281250 , -5840.218750 , -62.031250 };
		fSecondPills[4] = { -12687.187500 , -6407.750000 , 111.968750 };
		fSecondPills[5] = { -12715.000000 , -6068.000000 , 122.875000 };
		fSecondPills[6] = { -12507.000000 , -5884.000000 , 118.437500 };
		fSecondPills[7] = { -12760.000000 , -6000.000000 , 86.718750 };

		fThirdPills[0] = { -9988.156250 , -3842.781250 , -54.875000 };

		fFourthPills[0] = { -9382.500000 , -2802.281250 , -6.593750 };
		fFourthPills[1] = { -9282.000000 , -2737.000000 , 12.500000 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,7);
		third = GetRandomInt(0,0);
		fourth = GetRandomInt(0,1);
	}
	if (map == 204)
	{
		fFirstPills[0] = { -3190.812500 , 104.500000 , 357.843750 };

		fSecondPills[0] = { -263.000000 , -1870.000000 , -9.750000 };
		fSecondPills[1] = { -259.781250 , -1891.250000 , -8.812500 };
		fSecondPills[2] = { -519.500000 , -2331.906250 , -5.812500 };
		fSecondPills[3] = { -514.781250 , -2341.906250 , -5.812500 };

		fThirdPills[0] = { 2046.250000 , -2770.625000 , 241.406250 };

		fFourthPills[0] = { 1994.937500 , -3921.187500 , -24.375000 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,3);
		third = GetRandomInt(0,0);
		fourth = GetRandomInt(0,0);
	}
	if (map == 301)
	{
		fFirstPills[0] = { -7898.281250 , -14888.187500 , 339.468750 };

		fSecondPills[0] = { -10983.375000 , -13095.281250 , 624.250000 };
		fSecondPills[1] = { -11031.781250 , -12930.687500 , 587.687500 };
		fSecondPills[2] = { -10712.000000 , -12410.000000 , 481.156250 };
		fSecondPills[3] = { -10857.687500 , -12365.593750 , 463.375000 };
		fSecondPills[4] = { -10867.875000 , -12364.500000 , 463.281250 };

		fThirdPills[0] = { -11269.781250 , -10257.000000 , 480.531250 };
		fThirdPills[1] = { -11406.000000 , -10152.000000 , 479.937500 };
		fThirdPills[2] = { -11461.093750 , -9949.843750 , 478.250000 };
		fThirdPills[3] = { -11469.500000 , -9964.875000 , 479.281250 };
		fThirdPills[4] = { -11295.093750 , -9927.531250 , 449.937500 };
		fThirdPills[5] = { -11464.375000 , -9721.875000 , 503.812500 };
		fThirdPills[6] = { -11268.187500 , -9786.875000 , 479.937500 };
		fThirdPills[7] = { -11263.281250 , -9808.281250 , 478.218750 };

		fFourthPills[0] = { -6596.000000 , -8940.093750 , 368.000000 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,4);
		third = GetRandomInt(0,7);
		fourth = GetRandomInt(0,0);
	}	
	if (map == 302)
	{
		fFirstPills[0] = { -6344.062500 , -6393.500000 , 353.000000 };
		fFirstPills[1] = { -6348.875000 , -6402.593750 , 350.000000 };
		fFirstPills[2] = { -6427.125000 , -6391.937500 , 378.218750 };
		fFirstPills[3] = { -6490.500000 , -6590.656250 , 350.000000 };
		fFirstPills[4] = { -6512.437500 , -6354.406250 , 388.000000 };
		fFirstPills[5] = { -6503.843750 , -6297.968750 , 386.218750 };
		fFirstPills[6] = { -6513.625000 , -6121.406250 , 388.000000 };
		fFirstPills[7] = { -6448.906250 , -6031.062500 , 386.218750 };
		fFirstPills[8] = { -6274.843750 , -6025.625000 , 405.218750 };
		fFirstPills[9] = { -6265.531250 , -6028.906250 , 388.000000 };
		fFirstPills[10] = { -6218.625000 , -6059.125000 , 386.218750 };
		fFirstPills[11] = { -6279.218750 , -6217.968750 , 386.218750 };
		fFirstPills[12] = { -6327.437500 , -6219.718750 , 388.000000 };

		fSecondPills[0] = { -6380.875000 , -6547.562500 , 244.218750 };
		fSecondPills[1] = { -6502.906250 , -6635.562500 , 245.218750 };
		fSecondPills[2] = { -6495.218750 , -6900.250000 , 245.218750 };
		fSecondPills[3] = { -6471.500000 , -6039.281250 , 217.000000 };
		fSecondPills[4] = { -6479.812500 , -6045.343750 , 214.000000 };
		fSecondPills[5] = { -6671.781250 , -6031.781250 , 212.218750 };
		fSecondPills[6] = { -6470.250000 , -6912.218750 , 214.000000 };

		fThirdPills[0] = { -8671.000000 , -7514.718750 , -61.968750 };
		fThirdPills[1] = { -8677.093750 , -7523.000000 , -58.968750 };
		fThirdPills[2] = { -8695.593750 , -7500.187500 , -5.656250 };
		fThirdPills[3] = { -8525.000000 , -7339.000000 , -26.468750 };
		fThirdPills[4] = { -8525.000000 , -7340.000000 , -12.468750 };

		fFourthPills[0] = { -4787.000000 , -8035.000000 , -24.000000 };
		fFourthPills[1] = { -4567.593750 , -7989.968750 , -21.968750 };
		fFourthPills[2] = { -4560.656250 , -7982.375000 , -18.968750 };

		first = GetRandomInt(0,12);
		second = GetRandomInt(0,6);
		third = GetRandomInt(0,4);
		fourth = GetRandomInt(0,2);
	}
	if (map == 303)
	{
		fFirstPills[0] = { -858.593750 , -10431.687500 , -63.093750 };
		
		fSecondPills[0] = { -866.781250 , -10414.875000 , -60.937500 };

		fThirdPills[0] = { 1783.625000 , -12055.093750 , 205.875000 };
		fThirdPills[1] = { 1790.375000 , -12060.781250 , 202.000000 };
		fThirdPills[2] = { 1603.531250 , -12061.593750 , 262.000000 };
		fThirdPills[3] = { 1602.281250 , -12141.500000 , 318.218750 };

		fFourthPills[0] = { 6819.000000 , -12938.000000 , 20.687500 };
		fFourthPills[1] = { 6819.000000 , -12954.000000 , 20.687500 };
		fFourthPills[2] = { 6819.000000 , -12955.000000 , 6.687500 };
		fFourthPills[3] = { 6819.000000 , -12937.000000 , 6.687500 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,0);
		third = GetRandomInt(0,3);
		fourth = GetRandomInt(0,3);
	}
	if (map == 304)
	{
		fFirstPills[0] = { 7783.875000 , -11460.593750 , 494.281250 };
		fFirstPills[1] = { 7752.000000 , -11467.593750 , 494.281250 };
		
		fSecondPills[2] = { 7741.687500 , -11468.593750 , 492.375000 };
		fSecondPills[3] = { 7722.000000 , -11470.000000 , 494.281250 };

		fThirdPills[0] = { 10656.375000 , -8641.906250 , -11.250000 };
		fThirdPills[1] = { 10899.187500 , -9023.437500 , -10.093750 };
		fThirdPills[2] = { 11030.781250 , -8870.218750 , -10.093750 };
		fThirdPills[3] = { 11105.375000 , -8707.125000 , 23.718750 };
		fThirdPills[4] = { 11560.187500 , -7876.000000 , -10.093750 };
		fThirdPills[5] = { 11360.093750 , -8175.312500 , 44.718750 };
		fThirdPills[6] = { 11518.000000 , -8014.000000 , 46.875000 };
		fThirdPills[7] = { 10927.875000 , -7679.656250 , -66.250000 };
		fThirdPills[8] = { 10891.000000 , -7673.031250 , -66.093750 };
		fThirdPills[9] = { 10822.375000 , -7387.625000 , -66.093750 };
		fThirdPills[10] = { 10793.781250 , -7395.906250 , -35.125000 };
		fThirdPills[11] = { 10794.875000 , -7559.000000 , -35.000000 };
		fThirdPills[12] = { 10773.093750 , -7559.312500 , -34.093750 };
		fThirdPills[13] = { 10999.281250 , -7372.781250 , -66.093750 };
		fThirdPills[14] = { 11002.093750 , -7507.531250 , -4.250000 };
		
		fFourthPills[0] = { 10939.000000 , -5949.000000 , -35.531250 };
		fFourthPills[1] = { 11015.375000 , -5918.968750 , -53.093750 };
		fFourthPills[2] = { 11029.593750 , -5781.125000 , -38.093750 };


		first = GetRandomInt(0,1);
		second = GetRandomInt(0,3);
		third = GetRandomInt(0,14);
		fourth = GetRandomInt(0,2);
	}
	if (map == 401)
	{
		
		fFirstPills[0] = { 4874.500000 , -894.906250 , 677.125000 };
		fFirstPills[1] = { 4990.187500 , -175.062500 , 647.593750 };
		
		fSecondPills[0] = { 5094.093750 , 792.375000 , 575.218750 };

		fThirdPills[0] = { 3738.968750 , 568.875000 , 530.031250 };
		fThirdPills[1] = { 3358.593750 , 137.156250 , 564.000000 };

		fFourthPills[0] = { 3352.000000 , 1625.000000 , 402.031250 };
		fFourthPills[1] = { 2716.625000 , 1501.000000 , 434.187500 };


		first = GetRandomInt(0,1);
		second = GetRandomInt(0,0);
		third = GetRandomInt(0,1);
		fourth = GetRandomInt(0,1);
	}
	if (map == 402)
	{
		fFirstPills[0] = { 5303.062500 , 2721.406250 , 88.718750 };

		fSecondPills[0] = { 4496.281250 , 2691.218750 , 441.281250 };
		fSecondPills[1] = { 4699.500000 , 2305.906250 , 470.593750 };
		fSecondPills[2] = { 4696.187500 , 2923.437500 , 441.187500 };
		fSecondPills[3] = { 4749.343750 , 2824.000000 , 471.000000 };
		fSecondPills[4] = { 5190.937500 , 2492.656250 , 441.156250 };
		fSecondPills[5] = { 5634.000000 , 3238.000000 , 471.218750 };
		fSecondPills[6] = { 5227.906250 , 2306.593750 , 471.218750 };
		fSecondPills[7] = { 5285.500000 , 2383.468750 , 606.031250 };
		fSecondPills[8] = { 5423.437500 , 2868.906250 , 607.031250 };
		fSecondPills[9] = { 5325.437500 , 3092.750000 , 577.187500 };

		fThirdPills[0] = { 7658.218750 , 4280.625000 , 526.812500 };	//bridge
		
		fFourthPills[0] = { 8869.000000 , 4267.000000 , 691.343750 };	//pill cabinet
				
		first = GetRandomInt(0,0);
		second = GetRandomInt(0,9);
		third = GetRandomInt(0,0);
		fourth = GetRandomInt(0,0);
	}
	if (map == 403)
	{
		fFirstPills[0] = { -5381.843750 , -3168.312500 , 47.843750 };	//safe

		fSecondPills[0] = { -5392.187500 , -3175.656250 , 47.843750 };	//safe

		fThirdPills[0] = { -4060.000000 , 376.000000 , 28.218750 };
		fThirdPills[1] = { -4698.375000 , 56.906250 , 76.218750 };
		fThirdPills[2] = { -4875.406250 , 1407.125000 , 69.062500 };
		fThirdPills[3] = { -4048.250000 , 1127.218750 , 17.406250 };
			
		fFourthPills[0] = { -3100.968750 , 2563.968750 , 83.343750 };	//pill cabinet

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,0);
		third = GetRandomInt(0,3);
		fourth = GetRandomInt(0,0);
	}
	if (map == 404)
	{
		
		fFirstPills[0] = { 1365.343750 , 4646.687500 , 332.218750 };
		fFirstPills[1] = { 943.125000 , 4491.937500 , 330.125000 };
		
		fSecondPills[0] = { 105.843750 , 5504.843750 , 332.218750 };
		fSecondPills[1] = { -366.000000 , 5510.562500 , 297.406250 };
		fSecondPills[2] = { 278.656250 , 5207.531250 , 298.031250 };
		
		fThirdPills[0] = { 181.500000 , 2716.281250 , 16.218750 };
		
		fFourthPills[0] = { 1789.000000 , 1651.000000 , 49.312500 };
		fFourthPills[1] = { 1231.562500 , 1535.250000 , 17.218750 };		
		
		first = GetRandomInt(0,1);
		second = GetRandomInt(0,2);
		third = GetRandomInt(0,0);
		fourth = GetRandomInt(0,1);
	}
	if (map == 501)	//crash course 01 (hard to find spawns in rooms that are always open)
	{
		fFirstPills[0] = { -9852.406250 , -8694.406250 , -5.312500 };

		fSecondPills[0] = { -8883.093750 , -10832.187500 , 100.718750 }; //before 25%
		fSecondPills[1] = { -8166.750000 , -10269.593750 , 67.593750 };
		fSecondPills[2] = { -7590.625000 , -10029.375000 , 36.656250 };
		fSecondPills[3] = { -7732.156250 , -9708.218750 , 45.093750 };
		fSecondPills[4] = { -7716.781250 , -9700.843750 , 45.093750 };
		fSecondPills[5] = { -7425.375000 , -9796.000000 , 10.000000 };
		fSecondPills[6] = { -7370.968750 , -9756.093750 , 44.718750 };

		fThirdPills[0] = { -2274.812500 , -8474.281250 , 26.875000 }; //before 50 %
		fThirdPills[1] = { -2268.406250 , -8510.187500 , 26.156250 };
		fThirdPills[2] = { -2600.218750 , -8812.531250 , 49.968750 };
		fThirdPills[3] = { -2602.968750 , -8820.906250 , 49.968750 };
		fThirdPills[4] = { -2601.625000 , -8888.000000 , 48.687500 };
		fThirdPills[5] = { -2849.750000 , -8966.875000 , 1.656250 };
		fThirdPills[6] = { -2865.406250 , -8967.218750 , 1.656250 };	
		
		fFourthPills[0] = { -1195.343750 , -6321.062500 , -6.375000 }; //at event trigger
		fFourthPills[1] = { -1225.500000 , -6316.937500 , -2.125000 };
		fFourthPills[2] = { -1194.093750 , -6298.156250 , -2.125000 };
		fFourthPills[3] = { -1226.656250 , -6287.000000 , -4.187500 };
		fFourthPills[4] = { -2257.187500 , -6226.156250 , 91.656250 };
		fFourthPills[5] = { -2255.468750 , -6207.312500 , 91.500000 };
		fFourthPills[6] = { -2257.656250 , -6197.218750 , 89.812500 };
		fFourthPills[7] = { -2260.687500 , -6188.812500 , 89.875000 };
		fFourthPills[8] = { -2251.250000 , -5511.718750 , 69.468750 };
		fFourthPills[9] = { -2252.500000 , -5475.656250 , 67.875000 };
				
		first = GetRandomInt(0,0);
		second = GetRandomInt(0,6);
		third = GetRandomInt(0,6);
		fourth = GetRandomInt(0,9);
	}
	if (map == 502) //crash course 02 (hard to find spawns in rooms that are always open)
	{
		fFirstPills[0] = { 172.750000 , -1352.437500 , -135.718750 };

		fSecondPills[0] = { 1594.437500 , -1299.093750 , -139.218750 };
		fSecondPills[1] = { 1577.812500 , -1272.750000 , -138.187500 };
		fSecondPills[2] = { 1752.781250 , -749.343750 , -143.437500 };
		fSecondPills[3] = { 1819.968750 , -748.000000 , -142.218750 };
		fSecondPills[4] = { 1828.218750 , -750.750000 , -142.187500 };
		fSecondPills[5] = { 2433.718750 , 31.281250 , -156.750000 };
		fSecondPills[6] = { 2282.093750 , 259.531250 , -161.625000 };
		fSecondPills[7] = { 2305.656250 , 291.625000 , -163.187500 };
		fSecondPills[8] = { 2626.687500 , -730.218750 , -182.125000 };
		fSecondPills[9] = { 2629.531250 , -714.687500 , -183.687500 };
		fSecondPills[10] = { 2777.156250 , -742.218750 , -183.406250 };
		fSecondPills[11] = { 2771.218750 , -728.656250 , -185.000000 };
		fSecondPills[12] = { 2892.500000 , 237.968750 , -182.843750 };

		fThirdPills[0] = { 3332.468750 , 2725.468750 , -115.968750 };
		fThirdPills[1] = { 3298.062500 , 2777.187500 , -114.093750 };

		fFourthPills[0] = { 4406.500000 , 4908.000000 , 80.281250 };
		fFourthPills[1] = { 4425.218750 , 4913.531250 , 113.625000 };
		fFourthPills[2] = { 4260.093750 , 5042.375000 , 74.718750 };
		fFourthPills[3] = { 4330.781250 , 5667.906250 , 128.843750 };
		fFourthPills[4] = { 4327.968750 , 5675.187500 , 101.812500 };
		fFourthPills[5] = { 4277.250000 , 6561.187500 , 96.406250 };
		fFourthPills[6] = { 4279.437500 , 6536.906250 , 98.000000 };
		fFourthPills[7] = { 4700.968750 , 6452.437500 , 121.812500 };
		fFourthPills[8] = { 4704.218750 , 6428.250000 , 123.406250 };

		first = GetRandomInt(0,0);
		second = GetRandomInt(0,12);
		third = GetRandomInt(0,1);
		fourth = GetRandomInt(0,8);
	}
	if (map == 601) //sacrifice 01 (hard to find spawns in rooms that are always open)
	{
		fFirstPills[0] = { 10239.000000 , 554.000000 , 10.000000 };		//before dropping down to fight tank
		fFirstPills[1] = { 10196.000000 , 1357.000000 , 76.000000 };
		fFirstPills[2] = { 10197.000000 , 1342.000000 , 42.218750 };
		fFirstPills[3] = { 9910.093750 , 1754.468750 , 193.218750 };
		fFirstPills[4] = { 9914.187500 , 1767.906250 , 194.812500 };
		fFirstPills[5] = { 10165.500000 , 1637.375000 , 192.468750 };
		fFirstPills[6] = { 10168.781250 , 1622.625000 , 193.968750 };
		fFirstPills[7] = { 10577.687500 , 1855.750000 , 128.625000 };
		fFirstPills[8] = { 10581.000000 , 1841.000000 , 130.156250 };
		fFirstPills[9] = { 9062.843750 , 1607.000000 , 175.156250 };
		fFirstPills[10] = { 9072.750000 , 1613.750000 , 173.406250 };
		fFirstPills[11] = { 9106.000000 , 1174.000000 , 169.000000 };
		fFirstPills[12] = { 9004.250000 , 1172.500000 , 172.218750 };

		fSecondPills[0] = { 7990.625000 , 193.093750 , 1.218750 };		//at ammo or around there when fighting tank
		fSecondPills[1] = { 7990.437500 , 179.218750 , 4.187500 };
		fSecondPills[2] = { 7988.250000 , 160.406250 , 3.468750 };
		fSecondPills[3] = { 7987.406250 , 146.093750 , 1.125000 };
		fSecondPills[4] = { 8130.968750 , 157.125000 , 1.843750 };
		fSecondPills[5] = { 8134.875000 , 165.812500 , 1.656250 };
		fSecondPills[6] = { 8127.593750 , 169.281250 , 1.000000 };
		fSecondPills[7] = { 8129.375000 , 178.937500 , 1.406250 };
		fSecondPills[8] = { 8276.906250 , 704.218750 , 6.656250 };
		fSecondPills[9] = { 8228.593750 , 742.000000 , 5.875000 };

		fThirdPills[0] = { 6881.000000 , 596.000000 , 167.593750 };		//in container where tank spawns

		fFourthPills[0] = { 3490.781250 , 1381.281250 , 0.406250 };
		fFourthPills[1] = { 3501.937500 , 1389.812500 , 2.000000 };

		first = GetRandomInt(0,12);
		second = GetRandomInt(0,9);
		third = GetRandomInt(0,0);
		fourth = GetRandomInt(0,1);
	}
	if (map == 602)	//sacrifice 02 (hard to find spawns in rooms that are always open)
	{
		fFirstPills[0] = { 10760.875000 , 2350.531250 , 210.406250 };

		fSecondPills[0] = { 5971.656250 , 1674.000000 , 184.687500 };
		fSecondPills[1] = { 5974.000000 , 1660.125000 , 186.250000 };
		fSecondPills[2] = { 5760.250000 , 1073.031250 , 174.875000 };
		fSecondPills[3] = { 5746.812500 , 1077.156250 , 176.437500 };
		fSecondPills[4] = { 5565.031250 , 870.312500 , 176.437500 };
		fSecondPills[5] = { 5562.156250 , 882.187500 , 174.875000 };
		fSecondPills[6] = { 5301.656250 , 1252.093750 , 330.562500 };
		fSecondPills[7] = { 5315.093750 , 1248.000000 , 328.968750 };

		fThirdPills[0] = { 1163.593750 , 1499.281250 , -59.968750 };
		fThirdPills[1] = { 1176.812500 , 1495.187500 , -59.531250 };
		fThirdPills[2] = { 772.781250 , 1296.718750 , 9.562500 };
		fThirdPills[3] = { 780.031250 , 1345.031250 , 14.687500 };
		fThirdPills[4] = { 2103.812500 , 1592.000000 , 158.531250 };
		fThirdPills[5] = { 2090.875000 , 1597.468750 , 160.125000 };
		fThirdPills[6] = { 1914.000000 , 1324.000000 , 164.031250 };
		fThirdPills[7] = { 1893.531250 , 1362.093750 , 197.750000 };

		fFourthPills[0] = { -2922.968750 , 581.000000 , 280.500000 };
		fFourthPills[1] = { -2924.000000 , 581.000000 , 266.500000 };
		fFourthPills[2] = { -2906.000000 , 581.000000 , 266.500000 };
		fFourthPills[3] = { -2825.031250 , 544.250000 , 230.000000 };
		
		first = GetRandomInt(0,0);
		second = GetRandomInt(0,7);
		third = GetRandomInt(0,7);
		fourth = GetRandomInt(0,3);
	}
	if (map != 999 && map != 0)
	{
		new bool:pillsFoundFirst = false;
		new bool:pillsFoundSecond = false;
		new bool:pillsFoundThird = false;
		new bool:pillsFoundFourth = false;
		while ((entity = FindEntityByClassnameEx(entity, "weapon_pain_pills_spawn")) != -1)
		{
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);	
			if (ValidatePillSpawn(Float:entityPos[0], Float:fFirstPills[first][0], Float:entityPos[1], Float:fFirstPills[first][1], Float:entityPos[2], Float:fFirstPills[first][2]))
			{
				if(!pillsFoundFirst)
				{
					pills[0] = entity;
					pillsFoundFirst = true;
					continue;
				}
			}
			if (ValidatePillSpawn(Float:entityPos[0], Float:fSecondPills[second][0], Float:entityPos[1], Float:fSecondPills[second][1], Float:entityPos[2], Float:fSecondPills[second][2]))
			{
				if(!pillsFoundSecond)
				{
					pills[1] = entity;
					pillsFoundSecond = true;
					continue;
				}
			}
			if (ValidatePillSpawn(Float:entityPos[0], Float:fThirdPills[third][0], Float:entityPos[1], Float:fThirdPills[third][1], Float:entityPos[2], Float:fThirdPills[third][2]))
			{
				if(!pillsFoundThird)
				{
					pills[2] = entity;
					pillsFoundThird = true;
					continue;
				}
			}
			if (ValidatePillSpawn(Float:entityPos[0], Float:fFourthPills[fourth][0], Float:entityPos[1], Float:fFourthPills[fourth][1], Float:entityPos[2], Float:fFourthPills[fourth][2]))
			{
				if(!pillsFoundFourth)
				{
					pills[3] = entity;
					pillsFoundFourth = true;
					continue;
				}
			}
		}
	}
}

stock GetCurrentMapNumber()
{
	new map = 0;
	decl String:currentMap[256];	
	GetCurrentMap(currentMap, 256);
	
	if(StrContains(currentMap, "vs_hospital01", false) != -1)
	{
		map = 101;
	}
	else if(StrContains(currentMap, "vs_hospital02", false) != -1)
	{
		map = 102;
	}
	else if(StrContains(currentMap, "vs_hospital03", false) != -1)
	{
		map = 103;
	}
	else if(StrContains(currentMap, "vs_hospital04", false) != -1)
	{
		map = 104;
	}
	else if(StrContains(currentMap, "vs_smalltown01", false) != -1)
	{
		map = 201;
	}
	else if(StrContains(currentMap, "vs_smalltown02", false) != -1)
	{
		map = 202;
	}
	else if(StrContains(currentMap, "vs_smalltown03", false) != -1)
	{
		map = 203;
	}
	else if(StrContains(currentMap, "vs_smalltown04", false) != -1)
	{
		map = 204;
	}
	else if(StrContains(currentMap, "vs_farm01", false) != -1)
	{
		map = 301;
	}
	else if(StrContains(currentMap, "vs_farm02", false) != -1)
	{
		map = 302;
	}
	else if(StrContains(currentMap, "vs_farm03", false) != -1)
	{
		map = 303;
	}
	else if(StrContains(currentMap, "vs_farm04", false) != -1)
	{
		map = 304;
	}
	else if(StrContains(currentMap, "vs_airport01", false) != -1)
	{
		map = 401;
	}
	else if(StrContains(currentMap, "vs_airport02", false) != -1)
	{
		map = 402;
	}
	else if(StrContains(currentMap, "vs_airport03", false) != -1)
	{
		map = 403;
	}
	else if(StrContains(currentMap, "vs_airport04", false) != -1)
	{
		map = 404;
	}
	else if(StrContains(currentMap, "garage01", false) != -1)
	{
		map = 501;
	}
	else if(StrContains(currentMap, "garage02", false) != -1)
	{
		map = 502;
	}
	else if(StrContains(currentMap, "river01", false) != -1)
	{
		map = 601;
	}
	else if(StrContains(currentMap, "river02", false) != -1)
	{
		map = 602;
	}
	else if(StrContains(currentMap, "05", false) != -1)
	{
		map = 999;
	}
	return map;
}
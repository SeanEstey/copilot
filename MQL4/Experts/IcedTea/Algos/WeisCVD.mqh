//+------------------------------------------------------------------+
//|                                                 Algos/Volume.mqh |
//+------------------------------------------------------------------+

#property strict

int cvd_length=86;
bool cvd_combined=true;
bool cvd_relative=false;
int weis_difference=1000;
int weis_lblshift=150;
bool weis_showlabels=true;
int  weis_divby=1;
color weis_wave_color=clrBlueViolet;
int weis_wave_width=1;


//+------------------------------------------------------------------+
//| Returns: 1 for buy signal, -1 for short signal, 0 for no signal. |                                                                  |
//+------------------------------------------------------------------+
int GetSignal(){

   //  int sec = PeriodSeconds();
   
   // CVD Buffers: 0:Cum, 1:Pos, 2:Neg, 3:APos, 4:ANeg
   double cvdcum=iCustom(NULL,0,"IcedTea\\CVD",cvd_length,cvd_combined,cvd_relative,0,0);
   double cvdpos=iCustom(NULL,0,"IcedTea\\CVD",cvd_length,cvd_combined,cvd_relative,1,0);
   double cvdneg=iCustom(NULL,0,"IcedTea\\CVD",cvd_length,cvd_combined,cvd_relative,2,0);
   log("CVD Cum:"+(string)cvdcum+", Pos:"+(string)cvdpos+", Neg:"+(string)cvdneg);
   
   // Weis Buffers: 0:Up, 1:Down, 2:BarDir, 3:TrendDir, 4:WaveDir
   double up=iCustom(NULL,0,"IcedTea\\WeisWave",weis_difference,weis_lblshift,weis_showlabels,weis_divby,weis_wave_color,weis_wave_width,0,0); 
   double down=iCustom(NULL,0,"IcedTea\\WeisWave",weis_difference,weis_lblshift,weis_showlabels,weis_divby,weis_wave_color,weis_wave_width,1,0); 
   double bardir=iCustom(NULL,0,"IcedTea\\WeisWave",weis_difference,weis_lblshift,weis_showlabels,weis_divby,weis_wave_color,weis_wave_width,2,0);    
   double trenddir=iCustom(NULL,0,"IcedTea\\WeisWave",weis_difference,weis_lblshift,weis_showlabels,weis_divby,weis_wave_color,weis_wave_width,3,0);    
   double wavedir=iCustom(NULL,0,"IcedTea\\WeisWave",weis_difference,weis_lblshift,weis_showlabels,weis_divby,weis_wave_color,weis_wave_width,4,0); 
   log("Weis Up:"+(string)up+", Down:"+(string)down+", BarDir:"+(string)bardir+", TrendDir:"+(string)trenddir+", WaveDir:"+(string)wavedir);
   
   if(cvdcum > 0 && wavedir > 0)
      return 1;
   
   if(cvdcum < 0 && wavedir < 0)
      return -1;
      
   return 0;
}

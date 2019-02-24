//+------------------------------------------------------------------+
//|                                                 Algos/WeisCVD.mqh |
//+------------------------------------------------------------------+

#property strict

// Default indicator settings
#define CVD_PATH           "IcedTea\\CVD"
#define CVD_LENGTH         86
#define CVD_COMBINED       TRUE
#define CVD_RELATIVE       FALSE

#define WEIS_PATH          "IcedTea\\WeisWave"
#define WEIS_DIFF          1000
#define WEIS_LBLSHIFT      150
#define WEIS_SHOWLABELS    TRUE
#define WEIS_DIVBY         1
#define WEIS_WAVE_COLOR    clrBlueViolet
#define WEIS_WAVE_WIDTH    1

int last_weis=0;
enum Signals {NONE, OPEN_LONG, CLOSE_LONG, OPEN_SHORT, CLOSE_SHORT};

//+------------------------------------------------------------------+
//| Returns: Signal enum
//+------------------------------------------------------------------+
int GetSignal(){
   // CVD Buffers: 0:Cum, 1:Pos, 2:Neg, 3:APos, 4:ANeg
   int cvdlen=CVD_LENGTH;// * (3600*24 / PeriodSeconds());
   double cvdcum=iCustom(NULL,0,CVD_PATH,cvdlen,CVD_COMBINED,CVD_RELATIVE,0,0);
   double last_cvd=iCustom(NULL,0,CVD_PATH,cvdlen,CVD_COMBINED,CVD_RELATIVE,0,1);
   double cvdpos=iCustom(NULL,0,CVD_PATH,cvdlen,CVD_COMBINED,CVD_RELATIVE,1,0);
   double cvdneg=iCustom(NULL,0,CVD_PATH,cvdlen,CVD_COMBINED,CVD_RELATIVE,2,0);
   
   int weis=WeisWaveHeight(0);
   
   if(last_weis==0)
      last_weis=weis;
      

   if((weis>0 && last_weis<0) || (weis<0 && last_weis>0)){
       CreateVLine("WeisWave"+(string)Bars,0,0,0,clrBlue);
   }
   
   
   if(weis>0 && last_weis<0 && last_cvd>cvdcum){
      log("OPEN_LONG. New UpWave ("+(string)weis+") and Pos CVD ("+(string)cvdcum+")");
      last_weis=weis;
      return OPEN_LONG;
   }
   else if(weis<0 && last_weis>0 && last_cvd<cvdcum){
      log("OPEN_SHORT: New DownWave ("+(string)weis+") but Pos CVD ("+(string)cvdcum+")");
      last_weis=weis;
      return OPEN_SHORT;
   }
  /* else if(weis<0 && last_weis>0 && cvdcum<0){
      log("OPEN_SHORT: New DownWave ("+(string)weis+") and Neg CVD ("+(string)cvdcum+")");
      last_weis=weis;
      return OPEN_SHORT;
   }
   else if(weis>0 && last_weis<0 && cvdcum<0){
      log("CLOSE_SHORT. New UpWave ("+(string)weis+") but Neg CVD ("+(string)cvdcum+")");
      last_weis=weis;
      return CLOSE_SHORT;
   } */  /*
   // Prior Weis UpWave + CVD flips positive
   else if(weis>0 && last_weis>0 && cvdcum>0 && last_cvd<0){
      log("OPEN_LONG: CVD flipped positive ("+(string)cvdcum+")");
      last_weis=weis;
      return OPEN_LONG;
   }
   // Prior Weis DownWave + CVD flips negative
   else if(weis<0 && last_weis<0 && cvdcum<0 && last_cvd>0){
      log("OPEN_SHORT: CVD flipped negative ("+(string)cvdcum+")");
      last_weis=weis;
      return OPEN_SHORT;
   }*/
   last_weis=weis;
   return NONE;
}

int WeisWaveDir(int shift){
   // Weis Buffers: 0:Up, 1:Down, 2:BarDir, 3:TrendDir, 4:WaveDir
   return iCustom(NULL,0,WEIS_PATH,WEIS_DIFF,WEIS_LBLSHIFT,WEIS_SHOWLABELS,WEIS_DIVBY,WEIS_WAVE_COLOR,WEIS_WAVE_WIDTH,4,shift); 
}

int WeisWaveHeight(int shift){
   // Weis Buffers: 0:Up, 1:Down, 2:BarDir, 3:TrendDir, 4:WaveDir
   if(WeisWaveDir(shift)<0)
      return -1*iCustom(NULL,0,WEIS_PATH,WEIS_DIFF,WEIS_LBLSHIFT,WEIS_SHOWLABELS,WEIS_DIVBY,WEIS_WAVE_COLOR,WEIS_WAVE_WIDTH,1,shift); 
   else if(WeisWaveDir(shift)>0)
      return iCustom(NULL,0,WEIS_PATH,WEIS_DIFF,WEIS_LBLSHIFT,WEIS_SHOWLABELS,WEIS_DIVBY,WEIS_WAVE_COLOR,WEIS_WAVE_WIDTH,0,shift); 
   return 0;   
}

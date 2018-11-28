//+------------------------------------------------------------------+
//|                      Fisher Transform                            |
//|                        original Fisher routine by Yura Prokofiev |
//+------------------------------------------------------------------+
#include <utility.mqh>
#property description "Fisher Transform"
#property strict
#property indicator_separate_window
#property indicator_height 200
#property indicator_minimum -2
#property indicator_maximum 2
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red

//---- input parameters
sinput int FishLen      = 10;
sinput double FishBands = 1.0;

//---- indicator buffers
double FishSigBuf[];
double FishTrigBuf[];
double FishnValBuf[];

int subwindow_idx=NULL;
string high_band="Fisher OB Line";
string low_band="Fisher OS Line"; 

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //ObjectsDeleteAll(0, subwindow_idx, EMPTY); 
   ObjectDelete(0, low_band);
   ObjectDelete(0, high_band);
   return;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int OnInit()  {
   int id=0;
   string short_name="Fisher Transform("+FishLen+","+
      (string)(FishBands*-1)+","+(string)FishBands+")";
      
   IndicatorShortName(short_name);
   IndicatorBuffers(3);
   IndicatorDigits(2);
   
   SetIndexBuffer(0, FishSigBuf);
   SetIndexLabel(0, "Fisher Signal");
   ArraySetAsSeries(FishSigBuf,false);
   ArrayInitialize(FishSigBuf, 0);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2);
   
   SetIndexBuffer(1, FishTrigBuf);
   SetIndexLabel(1, "Fisher Trigger"); 
   ArraySetAsSeries(FishTrigBuf,false);
   ArrayInitialize(FishTrigBuf, 0);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,2);

   SetIndexBuffer(2, FishnValBuf);
   SetIndexLabel(2, "Fisher nVal"); 
   ArraySetAsSeries(FishnValBuf,false);
   ArrayInitialize(FishnValBuf, 0);
   SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,2);
   SetIndexEmptyValue(2,0.0); 
      
   // Upper/lower bands
   subwindow_idx=ChartWindowFind(id, short_name);
   if(subwindow_idx==-1)
      subwindow_idx=0;
      
   int res = ObjectCreate(id, low_band, OBJ_HLINE, subwindow_idx, Time[0], FishBands*-1);
   ObjectSetInteger(id, low_band, OBJPROP_COLOR, clrGreen); 
   ObjectSetInteger(id, low_band, OBJPROP_STYLE, STYLE_SOLID); 
   ObjectSetInteger(id, low_band, OBJPROP_WIDTH, 2); 
   ObjectSetInteger(id, low_band, OBJPROP_BACK, false); 
   ObjectSetInteger(id, low_band, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(id, low_band, OBJPROP_SELECTED, true); 
   ObjectSetInteger(id, low_band, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, low_band, OBJPROP_ZORDER, 0); 
   res = ObjectCreate(id, high_band, OBJ_HLINE, subwindow_idx, Time[0], FishBands);
   ObjectSetInteger(id, high_band, OBJPROP_COLOR, clrGreen); 
   ObjectSetInteger(id, high_band, OBJPROP_STYLE, STYLE_SOLID); 
   ObjectSetInteger(id, high_band, OBJPROP_WIDTH, 2); 
   ObjectSetInteger(id, high_band, OBJPROP_BACK, false); 
   ObjectSetInteger(id, high_band, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(id, high_band, OBJPROP_SELECTED, true); 
   ObjectSetInteger(id, high_band, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, high_band, OBJPROP_ZORDER, 0);  
   //if(!res)
   //   log("Error creating Fisher upper/lower band line. "+err_msg());
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
// The amount of bars not changed after the indicator had been launched last. 
// DO NOT MIX OLD STYLE (IndicatorCounted()) WITH NEW STYLE
//+------------------------------------------------------------------+
int OnCalculate (const int rates_total,      // size of input time series 
                 const int prev_calculated,  // bars handled in previous call 
                 const datetime& time[],     // Time 
                 const double& open[],       // Open 
                 const double& high[],       // High 
                 const double& low[],        // Low 
                 const double& close[],      // Close 
                 const long& tick_volume[],  // Tick Volume 
                 const long& volume[],       // Real Volume 
                 const int& spread[]         // Spread 
   ) {
   double MinL=0, MaxH=0, nVal2=0, hl2=0;
   int iBar,iTSBar;
 
   if(prev_calculated==0) {
      iBar=FishLen;
      ArrayInitialize(FishSigBuf,0);
      ArrayInitialize(FishTrigBuf,0);
      ArrayInitialize(FishnValBuf,0);
   }
   else {
      iBar=prev_calculated;
   }
   
   // iBar: non-Timeseries (left-to-right) index
   for(; iBar<rates_total; iBar++) { 
      if(iBar < 0 || iBar >= ArraySize(time)) { 
         log("Invalid iBar:"+iBar);
         return -1;
      } 
      iTSBar=Bars-iBar-1;  
      MaxH = High[iHighest(NULL,0,MODE_HIGH,FishLen,iTSBar)];
      MinL = Low[iLowest(NULL,0,MODE_LOW,FishLen,iTSBar)];
      hl2 = (High[iTSBar]+Low[iTSBar])/2;
      
      if(MaxH-MinL-0.5 == 0) {
         log("DivBy0 error. FishLen:"+(string)FishLen+", FishRange:"+(string)FishBands);
         continue;
      }
      FishnValBuf[iBar] = 0.33*2* ((hl2 - MinL) / (MaxH - MinL) - 0.5) + 0.67*FishnValBuf[iBar-1];    
      //nVal2 = nVal1 > 0.99 ? 0.999 : nVal1 < -0.99 ? -0.999 : nVal1;
      nVal2 = MathMin(MathMax(FishnValBuf[iBar],-0.999),0.999);
      FishSigBuf[iBar] = 0.5*MathLog((1+nVal2)/(1-nVal2)) + 0.5*FishSigBuf[iBar-1];
      FishTrigBuf[iBar] = FishSigBuf[iBar-1];
   }
   
   //printArray("FishSigBuf", FishSigBuf, iBar-10, 10, 1);
   //log("OnCalculate() done. PrevBars:"+prev_calculated+", NowBars:"+rates_total+", FishSigBuf.Size:"+ArraySize(FishSigBuf)+".");   
   return(rates_total);   
}
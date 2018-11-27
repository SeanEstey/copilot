//+------------------------------------------------------------------+
//|                               Based on Petr Doroshenko's original|
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+

#include <utility.mqh>
#property description "StochRSI"
#property strict
#property indicator_separate_window
#property indicator_height 350
#property indicator_minimum -5
#property indicator_maximum 105
#property indicator_buffers 3
#property indicator_color1 Blue
#property indicator_color2 Red
#property indicator_color3 Pink

//---- input parameters
extern int RSILen=14;
extern int KLen=10;
extern int DLen=3;
extern int Slowing=2;
extern int StochOB=80;
extern int StochOS=20;

double StochRSIBuf[];
double SigBuf[];
double RSIBuf[];
int RPrice=5;
int subwindow_idx=NULL;

int id=0;
string indicator = "StochRSI";
string signal = "Signal";
string lowerband = "Oversold Level";
string upperband = "Overbought Level";

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //Print("deinit StochRSI Indicator objects...");
   // ObjectsDeleteAll(0, subwindow_idx, EMPTY); 
   ObjectDelete(0, upperband);
   ObjectDelete(0, lowerband);
   return;
}


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   indicator += "("+RSILen+","+KLen+","+DLen+","+Slowing+")";
   
   IndicatorBuffers(3);
   IndicatorShortName(indicator);
   IndicatorDigits(1);
   
   SetIndexLabel(0,indicator);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2, clrBlue);
   SetIndexBuffer(0, StochRSIBuf);
   ArraySetAsSeries(StochRSIBuf,false);
   ArrayInitialize(StochRSIBuf,0);
   SetIndexDrawBegin(0,KLen+Slowing);
 
   SetIndexLabel(1,signal);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,2, clrRed);
   SetIndexBuffer(1, SigBuf);
   ArraySetAsSeries(SigBuf,false);
   ArrayInitialize(SigBuf,0);
   SetIndexDrawBegin(1,KLen+Slowing+DLen);
   SetIndexShift(1, Slowing*-1);
   
   SetIndexLabel(2,"RSI");
   SetIndexStyle(2,DRAW_LINE,STYLE_DOT,1, clrBlack);
   SetIndexBuffer(2, RSIBuf);   
   ArraySetAsSeries(RSIBuf,false);
   ArrayInitialize(RSIBuf,0);
   SetIndexDrawBegin(2,RSILen);  
  
   // upper/lower bands
   subwindow_idx=ChartWindowFind(id, indicator);
   if(subwindow_idx==-1)
      subwindow_idx=0;
   int res = ObjectCreate(id, lowerband, OBJ_HLINE, subwindow_idx, Time[0], StochOS);
   ObjectSetInteger(id, lowerband, OBJPROP_COLOR, clrBlack); 
   ObjectSetInteger(id, lowerband, OBJPROP_STYLE, 1); 
   ObjectSetInteger(id, lowerband, OBJPROP_WIDTH, 1); 
   ObjectSetInteger(id, lowerband, OBJPROP_BACK, false); 
   ObjectSetInteger(id, lowerband, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(id, lowerband, OBJPROP_SELECTED, true); 
   ObjectSetInteger(id, lowerband, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, lowerband, OBJPROP_ZORDER, 0); 
   res = ObjectCreate(id, upperband, OBJ_HLINE, subwindow_idx, Time[0], StochOB);
   ObjectSetInteger(id, upperband, OBJPROP_COLOR, clrBlack); 
   ObjectSetInteger(id, upperband, OBJPROP_STYLE, 1); 
   ObjectSetInteger(id, upperband, OBJPROP_WIDTH, 1); 
   ObjectSetInteger(id, upperband, OBJPROP_BACK, false); 
   ObjectSetInteger(id, upperband, OBJPROP_SELECTABLE, true); 
   ObjectSetInteger(id, upperband, OBJPROP_SELECTED, true); 
   ObjectSetInteger(id, upperband, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, upperband, OBJPROP_ZORDER, 0); 
   if(!res)
      log("Error creating upper/lower band line. "+err_msg());
   
   return(INIT_SUCCEEDED);
}
  
//+------------------------------------------------------------------+
//| Stochastics formula applied to RSI    
//| K: The time period to be used in calculating the %K. 3 is the default.
//| D: Percent of Deviation between price and the average of previous prices (Momentum). The time period to be used in calculating the %D. 3 is the default.                          |
//| 14 Day Stoch RSI = 1 when RSI is at its highest level in 14 Days.
//| 14 Day Stoch RSI = .8 when RSI is near the high of its 14 Day high/low range.
//| 14 Day Stoch RSI = .5 when RSI is in the middle of its 14 Day high/low range.
//| 14 Day Stoch RSI = .2 when RSI is near the low of its 14 Day high/low range.
//| 14 Day Stoch RSI = 0 when RSI is at its lowest level in 14 Days.

// The predefined arrays Close, High, Open, etc, are TimeSeries and ordered right to left
// To access a Timeseries use index=Bars -1- iBar
// and convert any results back index=Bars -1- result
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
   double low_rsi=0, high_rsi=0, sum_K=0;
   int iTSBar, iBar;
   
   if(prev_calculated==0) {
      iBar = MathMin(KLen+Slowing, RSILen);
      ArrayInitialize(StochRSIBuf,0);
      ArrayInitialize(SigBuf,0);
      ArrayInitialize(RSIBuf,0);
   }
   else {
      iBar = prev_calculated; // last bar becomes new index
   }
     
   // iBar: non-Timeseries (left-to-right) index
   for(; iBar<rates_total; iBar++) {  
      iTSBar=Bars-iBar-1;  
      sum_K=0;    
      double rsi=iRSI(NULL,0,RSILen,PRICE_TYPICAL,iTSBar);
      RSIBuf[iBar]=rsi;
      high_rsi=rsi;
      low_rsi=rsi;
      
      // K,D calculations
      for(int x=1;x<=KLen;x++){
         low_rsi=MathMin(low_rsi,iRSI(NULL,0,RSILen, PRICE_TYPICAL, iTSBar+x));
         high_rsi=MathMax(high_rsi,iRSI(NULL,0,RSILen,PRICE_TYPICAL, iTSBar+x));
      }
      for(int x=1;x<=DLen;x++){
         sum_K=sum_K + StochRSIBuf[iBar-x];
      }
      
      // StochRSI=(RSI-LowestRSI)/(HighestRSI-LowestRSI)
      if(high_rsi - low_rsi > 0)
         StochRSIBuf[iBar] = ((rsi-low_rsi)/(high_rsi-low_rsi))*100;
      else
         StochRSIBuf[iBar] = 100;
         
      SigBuf[iBar]=sum_K/DLen;
   }

   //arr_dump("StochRSIBuf", StochRSIBuf, iBar-10, 10, 1);
   //arr_dump("StochSigBuf", SigBuf, iBar-10, 10, 1);
   //log("OnCalculate() done. PrevBars:"+prev_calculated+", NowBars:"+rates_total+", StochRSIBufSize"+ArraySize(StochRSIBuf)+".");   
   return(rates_total);
}



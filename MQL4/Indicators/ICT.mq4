//+---------------------------------------------------------------------------+
//|                                                                   ICT.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property description "ICT"
#property strict
#property indicator_color1 Black

//---- Input params
sinput int MinImpulseStdDevs  =3;

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/PriceAction.mqh>
#include <FX/PriceMovement.mqh>
#include <FX/ChartObjects.mqh>

//--- Buffers
double MainBuf[];

//--- Dynamic arrays for tracking objects allocated on heap
string ChartObjs[1];
Candle* SwingLows[1];
Candle* SwingHighs[1];
Impulse* Impulses[1];          
OrderBlock* OrderBlocks[1];

//--- Global constants
string MainBufName             = "signal";
string ImpulseLblName          = "impulses";
string RetraceLblName          = "retraces";
string SwingHighLblName        = "swing_highs";
string SwingLowLblName         = "swing_lows";

//+---------------------------------------------------------------------------+
//| Custom indicator initialization function                                  |
//+---------------------------------------------------------------------------+
int OnInit() {
   ObjectsDeleteAll();   
   IndicatorBuffers(1);
   IndicatorShortName("ICT");
   IndicatorDigits(1);
   SetIndexLabel(0,MainBufName);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2, clrBlue);
   SetIndexBuffer(0, MainBuf);
   ArraySetAsSeries(MainBuf,true);
   SetIndexDrawBegin(0,1);
   CreateLabel("Last Impulse:",ImpulseLblName, 5,50);
   CreateLabel("Last Retrace:",RetraceLblName, 5,75);
   log("********** ICT Initialized **********");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   
   for(int i=0; i<ArraySize(Impulses); i++) {
      delete(Impulses[i]);
   }
   for(int i=0; i<ArraySize(SwingLows); i++) {
      delete(SwingLows[i]);
   }
   for(int i=0; i<ArraySize(SwingHighs); i++) {
      delete(SwingHighs[i]);
   }
   for(int i=0; i<ArraySize(OrderBlocks); i++) {
      delete(OrderBlocks[i]);
   }
   for(int i=0; i<ArraySize(ChartObjs); i++) {
      //ObjectDelete(ChartObjs[i]);
   }
   
   /*for(int i=0; i<ArraySize(ChartObjs); i++) {
      int r=ObjectDelete(ChartObjs[i]);
      log("deleted object "+(string)ChartObjs[i]+", result:"+(string)r+", Desc:"+GetLastError());
   }*/
   //ObjectsDeleteAll();
   log("********** ICT De-initialized **********");
   return;
}

//+---------------------------------------------------------------------------+
//| Custom indicator iteration function                                       |
//+---------------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{   
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   
   int iBar;   // TimeSeries
   if(prev_calculated==0) {
      iBar = 0;
      ArrayInitialize(MainBuf, EMPTY_VALUE);
   }
   else {
      iBar = prev_calculated+1;
      if(iBar>=Bars)
         return rates_total;
   }
 
   // Identify/annotate key daily swings
   for(int i=0; i<rates_total; i++){
     // FindDailyLevels(iBar, low, high, SwingLows, SwingHighs);
      //FindSwings(iBar, SwingLows, SwingHighs);
      MainBuf[iBar] = 0;
      iBar++;
   }
   
   DrawLevels(Symbol(), PERIOD_D1, 0, 100, clrRed, ChartObjs);
   DrawLevels(Symbol(), PERIOD_W1, 0, 10, clrBlue, ChartObjs);
   DrawLevels(Symbol(), PERIOD_MN1, 0, 6, clrGreen, ChartObjs);
   
   FindImpulses(iBar-rates_total,300, Impulses);
   //FindOrderBlocks(3.0, Impulses, OrderBlocks);
   
   log("Found "+(string)ArraySize(SwingHighs)+" SwingHighs and "+(string)ArraySize(SwingLows)+" SwingLows.");
   log("Found "+(string)ArraySize(Impulses)+" impulses!");   
   log("Price:"+(string)ToPipsStr(close[10]-Close[0])+" pips, Bar "+(string)iBar);
   
   log(Impulses[ArraySize(Impulses)-1].ToString());
   log(Impulses[ArraySize(Impulses)-2].ToString());
   log(Impulses[ArraySize(Impulses)-3].ToString());
   log(Impulses[ArraySize(Impulses)-4].ToString());
   log(Impulses[ArraySize(Impulses)-5].ToString());
   return(rates_total);  
}


   
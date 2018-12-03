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
sinput int ShortTermLen       =24;
sinput int MidTermLen         =10;
sinput int LongTermLen        =10;
sinput int MinImpulseStdDevs  =3;

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/PriceAction.mqh>
#include <FX/ChartObjects.mqh>

//--- Buffers
double MktStructBuf[];

//--- Globals
string ChartObjs[];
datetime SwingLows[];
datetime SwingHighs[];
OrderBlock OrderBlocks[];
Impulse Impulses[];           // Non-TimeSeries (left-to-right)

//--- Global constants
bool initHasRun            = false;
string mktStructLbl        = "Market Structure";
string mainLbl             = "Powered by ICT!";
string impulseLbl          = "Impulse Tracker";
string retraceLbl          = "Retrace Tracker";
string swingHighLbl        = "Swing Highs";
string swingLowLbl         = "Swing Lows";
const int SEC_PER_DAY      = 86400;


//+---------------------------------------------------------------------------+
//| Custom indicator initialization function                                  |
//+---------------------------------------------------------------------------+
int OnInit() {
   ObjectsDeleteAll();
      
   //--- indicator buffers mapping
   IndicatorBuffers(1);
   IndicatorShortName(mainLbl);
   IndicatorDigits(1);
    
   SetIndexLabel(0,mktStructLbl);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2, clrBlue);
   SetIndexBuffer(0, MktStructBuf);
   ArraySetAsSeries(MktStructBuf,true);
   SetIndexDrawBegin(0,1);

   ObjectCreate(0,impulseLbl,OBJ_LABEL,0,0,0);
   ObjectSetString(0,impulseLbl,OBJPROP_TEXT,"Last Impulse:");
   ObjectSetInteger(0,impulseLbl,OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,impulseLbl,OBJPROP_YDISTANCE,50);
   ObjectSetInteger(0,impulseLbl,OBJPROP_COLOR,clrBlack);
   
   ObjectCreate(0,retraceLbl,OBJ_LABEL,0,0,0);
   ObjectSetString(0,retraceLbl,OBJPROP_TEXT,"Last Retrace:");
   ObjectSetInteger(0,retraceLbl,OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,retraceLbl,OBJPROP_YDISTANCE,75);
   ObjectSetInteger(0,retraceLbl,OBJPROP_COLOR,clrBlack);
   
   ArrayResize(MktStructBuf,1);
   
   log(Symbol()+" digits:"+(string)MarketInfo(Symbol(),MODE_DIGITS)+", point:"+(string)MarketInfo(Symbol(),MODE_POINT)); 
   log("********** ICT Initialized **********");
   initHasRun=true;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   
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
      ArrayInitialize(MktStructBuf, EMPTY_VALUE);
      ArrayInitialize(SwingHighs, EMPTY_VALUE);
      ArrayInitialize(SwingLows, EMPTY_VALUE);
   }
   else {
      iBar = prev_calculated+1;
      if(iBar>=Bars)
         return rates_total;
   }
 
   // Identify/annotate key daily swings
   for(int i=0; i<rates_total; i++){
      FindSwings(iBar);
      MktStructBuf[iBar] = 0;
      iBar++;
   }
 
   FindImpulses(iBar-rates_total,300);
   log("Price:"+ToPipsStr(close[10]-Close[0])+" pips, Bar "+iBar);
   return(rates_total);  
}
//+---------------------------------------------------------------------------+
//|                                                          ICT.mq4 |
//|                                 Copyright 2018, Butch the Outlaw |
//|                                      https://www.outlawbutch.com |
//+---------------------------------------------------------------------------+
#include <utility.mqh>

#property copyright "Copyright 2018, Butch the Outlaw"
#property link      "https://www.outlawbutch.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property description "ICT"
#property strict
#property indicator_color1 Black

//---- Input params
sinput int ShortTermLen    =24;
sinput int MidTermLen      =10;
sinput int LongTermLen     =10;

//--- Buffers
double MktStructBuf[];

//--- Globals
datetime swinglows[];
datetime swinghighs[];
string ObjectList[];

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
   if(initHasRun)
      return(0);
      
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
   
   log("********** ICT Initialized **********");
   initHasRun=true;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   
   for(int i=0; i<ArraySize(ObjectList); i++) {
      int r=ObjectDelete(ObjectList[i]);
      log("deleted object "+(string)ObjectList[i]+", result:"+(string)r+", Desc:"+GetLastError());
   }
   ObjectsDeleteAll();
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
   int iBar;   // TimeSeries
   MqlDateTime dt1, dt2;
   
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   
   if(prev_calculated==0) {
      iBar = 0;
      ArrayInitialize(MktStructBuf, EMPTY_VALUE);
      ArrayInitialize(swinghighs, EMPTY_VALUE);
      ArrayInitialize(swinglows, EMPTY_VALUE);
   }
   else {
      iBar = prev_calculated+1;
      if(iBar>=Bars)
         return rates_total;
   }
 
   // Identify/annotate key daily swings
   for(int i=0; i<rates_total; i++){
      TimeToStruct(time[iBar], dt1);
      if(dt1.hour == 18 && dt1.min == 0) {
         CreateVLine(iBar+1, ObjectList);   
         TimeToStruct(time[iBar], dt2);
         dt2.day-=1;
         int dailybars = Bars(Symbol(),0, time[iBar],StructToTime(dt2));
         
         int iLBar = iLowest(Symbol(), 0, MODE_LOW, dailybars, iBar);
         CreateLine("daily_low_"+iBar, time[iBar], low[iLBar], StructToTime(dt2),
            low[iLBar], clrRed, ObjectList);
                  
         int iHBar = iHighest(Symbol(), 0, MODE_HIGH, dailybars, iBar);
         CreateLine("daily_high_"+iBar, time[iBar], high[iHBar], StructToTime(dt2),
            high[iHBar], clrRed, ObjectList);
         
         // Identify significant daily swings 
         if(isSwingLow(iLBar, low)) {
            CreateArrow("swinglow_"+iLBar, Symbol(), OBJ_ARROW_UP, iLBar, clrBlue, ObjectList);
            appendDtArray(swinglows, time[iLBar]);
            log("Found daily swinglow on "+TimeToStr(time[iLBar],TIME_DATE|TIME_MINUTES)+", Low:"+low[iLBar]);
         }
         if(isSwingHigh(iHBar,high)) {
            CreateArrow("swinghigh_"+iHBar, Symbol(), OBJ_ARROW_DOWN, iHBar, clrBlue, ObjectList);
            appendDtArray(swinglows, time[iHBar]);
            log("Found daily swinghigh on "+TimeToStr(time[iHBar],TIME_DATE|TIME_MINUTES)+", High:"+high[iHBar]);
         }
      }
      
      MktStructBuf[iBar] = 0;
      iBar++;
   }
 
   return(rates_total);
}


//+---------------------------------------------------------------------------+
//| Timer function                                                            |
//+---------------------------------------------------------------------------+
void OnTimer(){
   //log("Timer callback");
   //log("tracking "+(string)ArraySize(swinghighs)+" swinghighs.");
}


//+---------------------------------------------------------------------------+
//| ChartEvent function                                                       |
//+---------------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
}


//+---------------------------------------------------------------------------+
// ************************ Core Logic ***************************************/
//+---------------------------------------------------------------------------+


//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
bool isSwingHigh(int iBar, const double &highs[]) {
   if(iBar <=0 || iBar >=ArraySize(highs)-1)
      return false;
   if(highs[iBar] > highs[iBar+1] && highs[iBar] > highs[iBar-1])
      return true;
   else
      return false;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
bool isSwingLow(int iBar, const double &lows[]) {
   if(iBar<=0 || iBar>=ArraySize(lows)-1)
      return false;
   if(lows[iBar] < lows[iBar+1] && lows[iBar] < lows[iBar-1])
      return true;
   else
      return false;
}
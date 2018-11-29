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

//--- Price swing properties
struct impulse {
   int direction;    // 1:up, -1:down, 0:none
   int start_ibar;
   int end_ibar;
   datetime startdt;
   datetime enddt;
   double   height;
   double   std;
};

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
   
   /*for(int i=0; i<ArraySize(ObjectList); i++) {
      int r=ObjectDelete(ObjectList[i]);
      log("deleted object "+(string)ObjectList[i]+", result:"+(string)r+", Desc:"+GetLastError());
   }*/
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
      UpdateDailySwings(iBar);
      MktStructBuf[iBar] = 0;
      iBar++;
   }
 
   UpdateImpulseMoves(iBar-rates_total,30);
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
//| If iBar arrives at daily close, identify the significant swing highs/lows
//| for that week with chart annotations.
//+---------------------------------------------------------------------------+
void UpdateDailySwings(int iBar) {
   MqlDateTime dt1, dt2;
   TimeToStruct(Time[iBar], dt1);
   
   if(dt1.hour == 18 && dt1.min == 0) {
      CreateVLine(iBar+1, ObjectList);   
      TimeToStruct(Time[iBar], dt2);
      dt2.day-=1;
      int dailybars = Bars(Symbol(),0, Time[iBar],StructToTime(dt2));
      
      int iLBar = iLowest(Symbol(), 0, MODE_LOW, dailybars, iBar);
      int iHBar = iHighest(Symbol(), 0, MODE_HIGH, dailybars, iBar);
      
      CreateLine("daily_low_"+iBar, Time[iBar], Low[iLBar], StructToTime(dt2),
         Low[iLBar], clrRed, ObjectList);         
      CreateLine("daily_high_"+iBar, Time[iBar], High[iHBar], StructToTime(dt2),
         High[iHBar], clrRed, ObjectList);
      
      // Identify significant daily swings 
      if(isSwingLow(iLBar, Low)) {
         CreateArrow("swinglow_"+iLBar, Symbol(), OBJ_ARROW_UP, iLBar, clrBlue, ObjectList);
         appendDtArray(swinglows, Time[iLBar]);
         
         //log("Found daily swinglow on "+TimeToStr(Time[iLBar],TIME_DATE|TIME_MINUTES)+", Low:"+Low[iLBar]);
      }
      if(isSwingHigh(iHBar,High)) {
         CreateArrow("swinghigh_"+iHBar, Symbol(), OBJ_ARROW_DOWN, iHBar, clrBlue, ObjectList);
         appendDtArray(swinglows, Time[iHBar]);
         
         //log("Found daily swinghigh on "+TimeToStr(Time[iHBar],TIME_DATE|TIME_MINUTES)+", High:"+High[iHBar]);
      }
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void UpdateImpulseMoves(int iBar, int period) {
   impulse moves[];  // Non-TS (left-to-right index)
   
   for(int i=iBar; i<iBar+period; i++) {
      if(i==iBar) {
         // Init new impulse
         impulse x;
         x.direction=Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0;
         x.start_ibar=i;
         x.end_ibar=i;
         x.startdt=Time[i];
         x.enddt=Time[i];
         x.height=Close[i]-Open[i];
         
         // Save it
         ArrayResize(moves, ArraySize(moves)+1);
         moves[ArraySize(moves)-1]=x;
         continue;
      }
      
      int dir=Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0;
      impulse last = moves[ArraySize(moves)-1];
      
      // Merge properties of impulses chained together.
      // New impulse extends move by 1 bar to the left.
      // Extend startdt, start_ibar, and height
      if(last.direction == dir) {
         last.height=Close[last.end_ibar]-Open[i];
         last.start_ibar=i;
         last.startdt=Time[i];
      }
      // New impulse
      else {
         impulse x;
         x.direction=Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0;
         x.start_ibar=i;
         x.end_ibar=i;
         x.startdt=Time[i];
         x.enddt=Time[i];
         x.height=Close[i]-Open[i];
         ArrayResize(moves, ArraySize(moves)+1);
         moves[ArraySize(moves)-1]=x;
      }
   }
   
   log("Updated impulses from iBar "+iBar+"-"+(iBar+period)+". Impulses:"+(string)ArraySize(moves));
   
   double heights[];
   ArrayResize(heights,ArraySize(moves))
   ;
   for(int i=0; i<ArraySize(moves); i++) {
      heights[i] = moves[i].height;
   }
   double mean_height = Average(heights);
   double variance = Variance(heights, mean_height);
   double std = MathSqrt(variance);
   
   log("Mean impulse height:"+(string)mean_height+", Std_Dev:"+(string)std);
}

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
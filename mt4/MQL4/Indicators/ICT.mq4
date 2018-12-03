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
sinput int ShortTermLen       =24;
sinput int MidTermLen         =10;
sinput int LongTermLen        =10;
sinput int MinImpulseStdDevs  =3;

//--- Buffers
double MktStructBuf[];

//--- Structs
struct impulse {
   // Price swing properties
   int direction;    // 1:up, -1:down, 0:none
   int start_ibar;
   int end_ibar;
   int chainlen;
   int ob_ibar;
   datetime startdt;
   datetime enddt;
   double height;
   double n_deviations;
};

//--- Globals
string ChartObjs[];
datetime swinglows[];
datetime swinghighs[];
impulse impulses[];  // Non-TS (left-to-right)

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
   //if(initHasRun)
   //   return(0);
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
 
   UpdateImpulseMoves(iBar-rates_total,300);
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
// ************************ Price Action / ICT Methods ***********************/
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

//+---------------------------------------------------------------------------+
//| If iBar arrives at daily close, identify the significant swing highs/lows
//| for that week with chart annotations.
//+---------------------------------------------------------------------------+
void UpdateDailySwings(int iBar) {
   MqlDateTime dt1, dt2;
   TimeToStruct(Time[iBar], dt1);
   
   if(dt1.hour == 18 && dt1.min == 0) {
      CreateVLine(iBar+1, ChartObjs);   
      TimeToStruct(Time[iBar], dt2);
      dt2.day-=1;
      int dailybars = Bars(Symbol(),0, Time[iBar],StructToTime(dt2));
      
      int iLBar = iLowest(Symbol(), 0, MODE_LOW, dailybars, iBar);
      int iHBar = iHighest(Symbol(), 0, MODE_HIGH, dailybars, iBar);
      
      CreateLine("daily_low_"+(string)iBar, Time[iBar], Low[iLBar], StructToTime(dt2),
         Low[iLBar], clrRed, ChartObjs);         
      CreateLine("daily_high_"+(string)iBar, Time[iBar], High[iHBar], StructToTime(dt2),
         High[iHBar], clrRed, ChartObjs);
      
      // Identify significant daily swings 
      if(isSwingLow(iLBar, Low)) {
         CreateText("SL",iLBar,ANCHOR_UPPER,ChartObjs);
         appendDtArray(swinglows, Time[iLBar]);
      }
      if(isSwingHigh(iHBar,High)) {
         CreateText("SH",iHBar,ANCHOR_LOWER,ChartObjs);
         appendDtArray(swinglows, Time[iHBar]);
      }
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void UpdateImpulseMoves(int iBar, int period) {
   impulse moves[];
   double point=MarketInfo(Symbol(),MODE_POINT);
   
   for(int i=iBar; i<iBar+period; i++) {
      if(i==iBar) {
         // Init new impulse
         impulse x;
         x.direction=Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0;
         x.start_ibar=i;
         x.end_ibar=i;
         x.chainlen=1;
         x.startdt=Time[i];
         x.enddt=Time[i];
         x.height=(Close[i]-Open[i])/point;
         x.ob_ibar=-1;
         x.n_deviations=0;
         
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
         //log("Found an impulse chain!");
         last.height+=(Close[i]-Open[i])/point;
         last.start_ibar=i;
         last.chainlen++;
         last.startdt=Time[i];
         moves[ArraySize(moves)-1] = last;
      }
      // New impulse
      else {
         impulse x;
         x.direction=Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0;
         x.start_ibar=i;
         x.end_ibar=i;
         x.chainlen=1;
         x.startdt=Time[i];
         x.enddt=Time[i];
         x.height=(Close[i]-Open[i])/point;
         x.n_deviations=0;
         x.ob_ibar=-1;
         ArrayResize(moves, ArraySize(moves)+1);
         moves[ArraySize(moves)-1]=x;
      }
   }
   
   double heights[];
   ArrayResize(heights,ArraySize(moves));
   for(int i=0; i<ArraySize(moves); i++) {
      heights[i] = moves[i].height;
   }
   double mean_height = Average(heights);
   double variance = Variance(heights, mean_height);
   double std = MathSqrt(variance);
      
   for(int i=0; i<ArraySize(moves); i++){
      moves[i].n_deviations = moves[i].height/std;
      if(MathAbs(moves[i].n_deviations) >= MinImpulseStdDevs) {
         moves[i].ob_ibar=moves[i].start_ibar+1;
         ArrayResize(impulses, ArraySize(impulses)+1);
         // **** WARNING: PROBABLY NOT SAFE ********
         impulses[ArraySize(impulses)-1]=moves[i];
      }     
   }
   
   log("Updated impulses from iBar "+(string)iBar+"-"+(iBar+period)+". Impulses:"+(string)ArraySize(impulses));
   
   int max_up=0, max_down=0;
   for(int i=1; i<ArraySize(impulses); i++) {      
      if(impulses[i].height > impulses[max_up].height)
         max_up=i;
      else if(impulses[i].height < impulses[max_down].height)
         max_down=i;
   }
   
   impulses[max_up].n_deviations = impulses[max_up].height/std;
   if(MathAbs(impulses[max_up].n_deviations) >= 3)
      impulses[max_up].ob_ibar=impulses[max_up].start_ibar+1;
      
   impulses[max_down].n_deviations = impulses[max_down].height/std;
   if(MathAbs(impulses[max_down].n_deviations) >= 3)
      impulses[max_down].ob_ibar=impulses[max_down].start_ibar+1;
   
   log("Mean chain height:"+DoubleToStr(mean_height,2)+" pips, Std_Dev:"+DoubleToStr(std,2)+" pips");
   
   // Draw OB Rectangles
   
   int OB_RECT_WIDTH=50;
   datetime dt1=iTime(Symbol(),0,impulses[max_up].ob_ibar);
   double p1=iHigh(Symbol(),0,impulses[max_up].ob_ibar);
   datetime dt2;
   if(impulses[max_up].ob_ibar-OB_RECT_WIDTH < 0)
      dt2=iTime(Symbol(),0,0);
   else
      dt2=iTime(Symbol(),0,impulses[max_up].ob_ibar-OB_RECT_WIDTH);
   double p2=iLow(Symbol(),0,impulses[max_up].ob_ibar);
   CreateRect(dt1,p1,dt2,p2,ChartObjs);
   
   log(impulseToStr(impulses[max_up], std));
   log(impulseToStr(impulses[max_down], std));
 
}

//+----------------+-----------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
string impulseToStr(impulse& x, double std) {
   double point=MarketInfo(Symbol(),MODE_POINT);
   string dir= x.direction == 1 ? "upward" : x.direction==-1 ? "downward" : "sideways"; 
   string s = TimeToStr(x.startdt)+": "+(string)x.chainlen+"-chain "+dir+" impulse, height:"+DoubleToStr(x.height,2)+" pips, "+DoubleToStr(x.n_deviations,2)+"x STD. ";
   if(x.ob_ibar >=0)
      s+=" Parent OrderBlock: iBar["+(string)x.ob_ibar+"]";
   return s;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
string GetOrderBlockDesc(int iBar) {
   return "";
}
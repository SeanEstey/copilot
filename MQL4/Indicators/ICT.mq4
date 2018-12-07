//+---------------------------------------------------------------------------+
//|                                                                   ICT.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property description "ICT"
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red
#property strict

#define KEY_L     76
#define KEY_S     83
#define EMA1_BUF_NAME   "ema_fast"
#define EMA2_BUF_NAME   "ema_slow"
#define IMP_HUD_NAME    "impulses_hud"
#define OB_HUD_NAME     "ob_hud"
#define SH_HUD_NAME     "sh_hud"
#define SL_HUD_NAME     "sl_hug"
#define TREND_HUD_NAME  "trend"

//---- Inputs
sinput int EMA1_Period           =9;
sinput int EMA2_Period           =18;
sinput double MinImpulseStdDevs  =3;

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/PriceAction.mqh>
#include <FX/PriceMovement.mqh>
#include <FX/ChartObjects.mqh>

//--- Indicator Buffers
double Ema1Buf[];
double Ema2Buf[];

//--- Dynamic pointer arrays (
string ChartObjs[];
Candle* SL[];
Candle* SH[];
Impulse* Impulses[];          
OrderBlock* OrderBlocks[];


//--- Hud State Globals
/*** TODO: encapsulate into class ***/
int VislbleHH              = 0;
int VisibleLL              = 0;
bool ShowLevels            = true;
bool ShowSwings            = true;
int  Trend                 = 0;


//+---------------------------------------------------------------------------+
//| Custom indicator initialization function                                  |
//+---------------------------------------------------------------------------+
int OnInit() { 
   // Init indicator
  // ObjectsDeleteAll();   
   IndicatorShortName("ICT");
   IndicatorDigits(3);
   IndicatorBuffers(2);
   
   // Init buffers
   SetIndexLabel(0,EMA1_BUF_NAME);
   SetIndexStyle(0,DRAW_LINE,STYLE_DASH,2, clrMediumTurquoise);
   SetIndexBuffer(0, Ema1Buf);
   ArraySetAsSeries(Ema1Buf,true);
   ArrayInitialize(Ema1Buf,0);
   
   SetIndexLabel(1,EMA2_BUF_NAME);
   SetIndexStyle(1,DRAW_LINE,STYLE_DASH, 2, clrOrange);
   SetIndexBuffer(1, Ema2Buf);
   ArraySetAsSeries(Ema2Buf,true);
   ArrayInitialize(Ema2Buf,0);
   
   // Hud labels
   CreateLabel("",SH_HUD_NAME, 5,50);
   CreateLabel("",SL_HUD_NAME, 5,90);
   CreateLabel("",TREND_HUD_NAME,5,130);
   
   log("********** ICT Initialized **********");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   
   for(int i=0; i<ArraySize(ChartObjs); i++)
      ObjectDelete(ChartObjs[i]);
   for(int i=0; i<ArraySize(Impulses); i++)
      delete(Impulses[i]);
   for(int i=0; i<ArraySize(SL); i++)
      delete(SL[i]);
   for(int i=0; i<ArraySize(SH); i++)
      delete(SH[i]);
   for(int i=0; i<ArraySize(OrderBlocks); i++)
      delete(OrderBlocks[i]);
      
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
   
   int pos;   // TimeSeries
   if(prev_calculated==0) {
      pos=rates_total-1;
      ArrayInitialize(Ema1Buf, EMPTY_VALUE);
      ArrayInitialize(Ema2Buf, EMPTY_VALUE);
   }
   else {
      pos = prev_calculated-rates_total+1;
      if(pos>=Bars)
         return rates_total;
   }
 
   int buf1_tf_period=GetAdjustedPeriod(EMA1_Period);
   int buf2_tf_period=GetAdjustedPeriod(EMA2_Period);
   
   // Main buffer loop
   for(; pos>0; pos--){
      Ema1Buf[pos] = iMA(Symbol(),0,buf1_tf_period,0,MODE_EMA,PRICE_CLOSE,pos);
      Ema2Buf[pos] = iMA(Symbol(),0,buf2_tf_period,0,MODE_EMA,PRICE_CLOSE,pos);
   }
      
   DrawHud(time, high, low);
   //FindImpulses(prev_calculated+1, 1000, Impulses, MinImpulseStdDevs, ChartObjs);
   log("OnCalc updated "+(string)rates_total+" bars");
   return(rates_total);  
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int GetTrend(){
   double ema1=Ema1Buf[1];
   double ema2=Ema2Buf[1];
   
   // Crossover
   if(ema1>ema2) {
      log("EMA Crossover ("+DoubleToStr(ema1,3)+">"+DoubleToStr(ema2,3)+")");
      return 1;
   }
   // Crossunder
   else if(ema1<ema2) {
      log("EMA Crossunder ("+DoubleToStr(ema1,3)+"<"+DoubleToStr(ema2,3)+")");
      return -1;
   }
   
   log("No trend ("+DoubleToStr(ema1,3)+"=="+DoubleToStr(ema2,3)+")");
   return 0;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void DrawHud(const datetime &time[], const double &high[], const double &low[]) {
   
   DrawSwingLabels(Symbol(), 0, 10000, 0, clrBlack, low, high, SL, SH, ChartObjs);
   DrawLevels(Symbol(), PERIOD_D1, 0, 100, clrRed, ChartObjs);
   //DrawLevels(Symbol(), PERIOD_W1, 0, 10, clrBlue, ChartObjs);
   //DrawLevels(Symbol(), PERIOD_MN1, 0, 6, clrGreen, ChartObjs);
   
   // HUD Stats
   int VisibleHH=GetSignificantVisibleSwing(SWING_HIGH, SH);
   ObjectSetString(0,SH_HUD_NAME,OBJPROP_TEXT,
      "Highest SH: "+(string)high[VisibleHH]+" ("+TimeToStr(time[VisibleHH])+")"); 
   int VisibleLL=GetSignificantVisibleSwing(SWING_LOW, SL);
   ObjectSetString(0,SL_HUD_NAME,OBJPROP_TEXT,
      "Lowest SL: "+(string)low[VisibleLL]+" ("+TimeToStr(time[VisibleLL])+")"); 
   
   // Bullish/Bearish trend display
   int trend=GetTrend();
   string trend_text = trend==1 ? "Trend: Bullish AF" : trend==-1 ? "Trend: Bearish AF" : "Trend: None";
   ObjectSetString(0,TREND_HUD_NAME,OBJPROP_TEXT, trend_text);
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void OnChartEvent(const int id,         // Event ID 
                  const long& lparam,   // Parameter of type long event 
                  const double& dparam, // Parameter of type double event 
                  const string& sparam  // Parameter of type string events 
  ){
   if(id==CHARTEVENT_CLICK) { 
      log("Clicked chart coords x:"+(string)lparam+", y:"+(string)dparam);
   } 
   else if(id==CHARTEVENT_OBJECT_CLICK) { 
      log("Clicked object '"+sparam+"'"); 
   } 
   //--- the key has been pressed 
   else if(id==CHARTEVENT_KEYDOWN) { 
      switch(lparam) { 

         // Toggle Swing Candle labels
         case KEY_S: 
            ShowSwings = ShowSwings ? false : true;
            
            for(int i=0; i<ArraySize(SH); i++) {
               SH[i].Annotate(ShowSwings);
            }
            for(int i=0; i<ArraySize(SL); i++) {
               SL[i].Annotate(ShowSwings);
            }
            
            log("ShowSwings:"+(string)ShowSwings);
            break;
         
         // Toggle horizontal level lines
         case KEY_L:
            if(ShowLevels==true) {
               for(int i=0; i<ArraySize(ChartObjs); i++) {
                  if(ObjectType(ChartObjs[i])==OBJ_TREND)
                     ObjectDelete(ChartObjs[i]);
               }
               ShowLevels=false;
            }
            else {
               DrawLevels(Symbol(), PERIOD_D1, 0, 100, clrRed, ChartObjs);
               DrawLevels(Symbol(), PERIOD_W1, 0, 10, clrBlue, ChartObjs);
               DrawLevels(Symbol(), PERIOD_MN1, 0, 6, clrGreen, ChartObjs);
               ShowLevels=true;
            }
            log("ShowLevels:"+(string)ShowLevels);
            break;
            
         default: 
            log("Unmapped key:"+(string)lparam); 
      } 
      ChartRedraw(); 
   }
   else if(id==CHARTEVENT_CHART_CHANGE) {
      //Change of the chart size or modification of chart properties through the Properties dialog
      //log("new chart");
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int GetAdjustedPeriod(int daily_period){
   if(PERIOD_CURRENT > PERIOD_D1) {
      log("Cannot scale period higher than Daily!");
      return -1;
   }
   
   int period=daily_period*(PERIOD_D1/Period());
   
   if(period >= Bars) {
      log("AdjustedPeriod "+(string)daily_period+"-->"+(string)period+" exceeds Bars!");
      return -1;
   }
   return period;
}
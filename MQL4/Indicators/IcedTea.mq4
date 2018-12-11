//+---------------------------------------------------------------------------+
//|                                                               IcedTea.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property description "IcedTea Robot"
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red
#property strict

//--- Keyboard inputs
#define KEY_L           76
#define KEY_S           83
#define EMA1_BUF_NAME   "EMA_FAST"
#define EMA2_BUF_NAME   "EMA_SLOW"
#define V_CROSSHAIR     "V_CROSSHAIR"
#define H_CROSSHAIR     "H_CROSSHAIR"

//---- Inputs
sinput int EMA1_Period           =9;
sinput int EMA2_Period           =18;
sinput double MinImpulseStdDevs  =3;

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/Chart.mqh>
#include <FX/Swings.mqh>
#include <FX/Impulses.mqh>
#include <FX/Draw.mqh>
#include <FX/Hud.mqh>


//--- Indicator Buffers
double Ema1Buf[];
double Ema2Buf[];

//--- Dynamic pointer arrays
string ChartObjs[];
Swing* Lows[];
Swing* Highs[];
Impulse* Impulses[];          
OrderBlock* OrderBlocks[];

//--- Globals
HUD* Hud                   = NULL;
bool ShowLevels            = false;
bool ShowSwings            = true;


//+---------------------------------------------------------------------------+
//| MQL4 Callback Method                                                      |
//+---------------------------------------------------------------------------+
int OnInit() { 
   /* Init indicator & chart */
  
   IndicatorShortName("IcedTea");
   IndicatorDigits(3);
   IndicatorBuffers(2);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE,true);
 
   
   
   /* Init Buffers */
   
   SetIndexLabel(0,EMA1_BUF_NAME);
   SetIndexStyle(0,DRAW_LINE,STYLE_DASH,2, clrMediumTurquoise);
   SetIndexBuffer(0, Ema1Buf);
   ArraySetAsSeries(Ema1Buf,true);
   ArrayInitialize(Ema1Buf, EMPTY_VALUE);
   
   SetIndexLabel(1,EMA2_BUF_NAME);
   SetIndexStyle(1,DRAW_LINE,STYLE_DASH, 2, clrOrange);
   SetIndexBuffer(1, Ema2Buf);
   ArraySetAsSeries(Ema2Buf,true);
   ArrayInitialize(Ema2Buf, EMPTY_VALUE);
   
   /* Init custom modules */
   Hud = new HUD();
   Hud.AddItem("hud_title","IcedTea HUD","");
   Hud.AddItem("hud_hover_bar","Hover Bar","");
   Hud.AddItem("hud_window_bars","Bars","");
   Hud.AddItem("hud_highest_high","High","");
   Hud.AddItem("hud_lowest_low", "Low", "");
   Hud.AddItem("hud_trend", "Trend", "");
   
  
   log("********** IcedTea Initialized **********");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| MQL4 Callback Method                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   
   delete Hud;
   ObjectDelete(0,V_CROSSHAIR);
   ObjectDelete(0,H_CROSSHAIR);
   
   for(int i=0; i<ArraySize(ChartObjs); i++)
      ObjectDelete(ChartObjs[i]);
   for(int i=0; i<ArraySize(Impulses); i++)
      delete(Impulses[i]);
   for(int i=0; i<ArraySize(Lows); i++)
      delete Lows[i];
   for(int i=0; i<ArraySize(Highs); i++)
      delete(Highs[i]);
   for(int i=0; i<ArraySize(OrderBlocks); i++)
      delete(OrderBlocks[i]);
      
   log("********** IcedTea Deinit **********");
   return;
}

//+---------------------------------------------------------------------------+
//| MQL4 Callback Method
//| prev_calculated is reset to 0 on chart change or new price data           |
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
    
   }
   else {
      pos = rates_total-prev_calculated;
      if(pos>=Bars)
         return rates_total;
   }
 
   int ema1_len=ScalePeriod(EMA1_Period);
   int ema2_len=ScalePeriod(EMA2_Period);
   
   // Main buffer loop..
   for(int i=pos; i>=0; i--){
      //Ema1Buf[i] = iMA(Symbol(),0,ema1_len,0,MODE_EMA,PRICE_CLOSE,i);
      //Ema2Buf[i] = iMA(Symbol(),0,ema2_len,0,MODE_EMA,PRICE_CLOSE,i);
   }
   
   if(pos>0) {
      UpdateSwings(Symbol(), 0, Bars, 0, clrBlack, low, high, Lows, Highs, ChartObjs);
      //DrawLevels(Symbol(), PERIOD_D1, 0, 100, clrRed, ChartObjs);
      //DrawLevels(Symbol(), PERIOD_W1, 0, 10, clrBlue, ChartObjs);
      //DrawLevels(Symbol(), PERIOD_MN1, 0, 6, clrGreen, ChartObjs);
      ShowSwingVariances(Symbol(),0,Highs,ChartObjs);
      ShowSwingVariances(Symbol(),0,Lows,ChartObjs);
      
      log("OnCalc updated "+(string)+pos+" bars. prev:"+(string)prev_calculated+", rates_total:"+(string)rates_total);
   }
   return(rates_total);  
}

//+---------------------------------------------------------------------------+
//| MQL4 Callback Method                                                      |
//+---------------------------------------------------------------------------+
void OnChartEvent(const int id,         // Event ID 
                  const long& lparam,   // Parameter of type long event 
                  const double& dparam, // Parameter of type double event 
                  const string& sparam  // Parameter of type string events 
  ){
   if(id==CHARTEVENT_MOUSE_MOVE) {
      int bar=CoordsToBar((int)lparam, (int)dparam);
      Hud.SetItemValue("hud_hover_bar",(string)bar);
      DrawCrosshair(lparam, (long)dparam);
      //debuglog("Mouse move. Coords:["+(string)lparam+","+(string)dparam+"]"+", sparam:"+sparam);
   }
   else if(id==CHARTEVENT_CLICK) { 
      //log("Mouse click. lparam:"+(string)lparam+", dparam:"+(string)dparam+", sparam:"+(string)sparam);
   } 
   else if(id==CHARTEVENT_OBJECT_CLICK) { 
      //log("Clicked object '"+sparam+"'"); 
   }
   else if(id==CHARTEVENT_CHART_CHANGE) {
      /* Update HUD */
      int first = WindowFirstVisibleBar();
      int last = first-WindowBarsPerChart();
      Hud.SetItemValue("hud_window_bars",(string)(last+2)+"-"+(string)(first+2));
   
      int hh_shift=iHighest(Symbol(),0,MODE_HIGH,first-last,last);
      int ll_shift=iLowest(Symbol(),0,MODE_LOW,first-last,last);   
      double hh=iHigh(Symbol(),0,hh_shift);
      datetime hh_time=iTime(Symbol(),0,hh_shift);
      double ll=iLow(Symbol(),0,ll_shift);
      datetime ll_time=iTime(Symbol(),0,ll_shift);
      Hud.SetItemValue("hud_lowest_low", DoubleToStr(ll,3)+" [Bar "+(string)(ll_shift+2)+"]"); 
      Hud.SetItemValue("hud_highest_high", DoubleToStr(hh,3)+" [Bar "+(string)(hh_shift+2)+"]");
    
      int trend=GetTrend();
      Hud.SetItemValue("hud_trend", trend==1? "Bullish" : trend==-1? "Bearish" : "N/A");
   
   }
   //--- the key has been pressed 
   else if(id==CHARTEVENT_KEYDOWN) { 
      switch(lparam) { 

         // Toggle Swing Candle labels
         case KEY_S: 
            ShowSwings = ShowSwings ? false : true;
            
            for(int i=0; i<ArraySize(Highs); i++) {
               Highs[i].Annotate(ShowSwings);
            }
            for(int i=0; i<ArraySize(Lows); i++) {
               Lows[i].Annotate(ShowSwings);
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
               DrawFixedRanges(Symbol(), PERIOD_D1, 0, 100, clrRed, ChartObjs);
               DrawFixedRanges(Symbol(), PERIOD_W1, 0, 10, clrBlue, ChartObjs);
               DrawFixedRanges(Symbol(), PERIOD_MN1, 0, 6, clrGreen, ChartObjs);
               ShowLevels=true;
            }
            log("ShowLevels:"+(string)ShowLevels);
            break;
            
         default:
            debuglog("Unmapped key:"+(string)lparam); 
            break;
      } 
      ChartRedraw(); 
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int GetTrend(){
   double ema1=iMA(Symbol(),0,9,0,MODE_EMA,PRICE_CLOSE,0);
   double ema2=iMA(Symbol(),0,18,0,MODE_EMA,PRICE_CLOSE,0);
   
   // Crossover
   if(ema1>ema2) {
      debuglog("EMA Crossover ("+DoubleToStr(ema1,3)+">"+DoubleToStr(ema2,3)+")");
      return 1;
   }
   // Crossunder
   else if(ema1<ema2) {
      debuglog("EMA Crossunder ("+DoubleToStr(ema1,3)+"<"+DoubleToStr(ema2,3)+")");
      return -1;
   }
   
   log("No trend ("+DoubleToStr(ema1,3)+"=="+DoubleToStr(ema2,3)+")");
   return 0;
}

//+---------------------------------------------------------------------------+-
//| 
//+---------------------------------------------------------------------------+
int DrawCrosshair(long x, long y) {
   datetime dt;
   double price;
   int window=0;
   ChartXYToTimePrice(0,x,y,window,dt,price);
      
   // Create crosshair
   if(ObjectFind((string)V_CROSSHAIR)==-1){
      CreateHLine(H_CROSSHAIR,price,0,0,clrBlack,0,1,false,false,-100);
      CreateVLine(V_CROSSHAIR,CoordsToBar(x,y),ChartObjs,0,0,clrBlack,0,1,false,false,true,-100);
      debuglog("Created crosshair");
   }
   // Move crosshair to new mouse pos
   else {
      ObjectMove(0,H_CROSSHAIR,0,0,price);
      ObjectMove(0,V_CROSSHAIR,0,dt,0);
      //debuglog("Moved crosshair to dt:"+(string)dt+", p:"+DoubleToStr(price,3));
   }
   return 1;
}
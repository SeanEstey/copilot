//+---------------------------------------------------------------------------+
//|                                                               IcedTea.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+

#define VERSION "0.1"
#property version VERSION
#property copyright "Copyright 2018, Sean Estey"
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


//---- Inputs
sinput int EMA1_Period           =9;
sinput int EMA2_Period           =18;
sinput double MinImpulseStdDevs  =3;

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/Chart.mqh>
#include <FX/SwingPoints.mqh>
#include <FX/Draw.mqh>
#include <FX/Hud.mqh>


//--- Indicator Buffers
double Ema1Buf[];
double Ema2Buf[];

//--- Dynamic pointer arrays
//Impulse* Impulses[];          
//OrderBlock* OrderBlocks[];

//--- Globals
HUD* Hud                   = NULL;
SwingGraph* Swings         = NULL;
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
   Hud = new HUD("IcedTea v"+VERSION);
   Hud.AddItem("hud_hover_bar","Hover Bar","");
   Hud.AddItem("hud_window_bars","Bars","");
   Hud.AddItem("hud_highest_high","Highest High","");
   Hud.AddItem("hud_lowest_low", "Lowest Low", "");
   Hud.AddItem("hud_trend", "EMA Trend", "");
   Hud.AddItem("hud_nodes", "Swing Nodes", "");
   Hud.AddItem("hud_node_links", "Node Links", "");
   
   Swings = new SwingGraph();
  
   log("********** IcedTea Initialized **********");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| MQL4 Callback Method                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   
   delete Hud;
   delete Swings;
   ObjectDelete(0,V_CROSSHAIR);
   ObjectDelete(0,H_CROSSHAIR);
   //for(int i=0; i<ArraySize(Impulses); i++)
   //   delete(Impulses[i]);
   //for(int i=0; i<ArraySize(OrderBlocks); i++)
   //   delete(OrderBlocks[i]);
      
   ObjectsDeleteAll(0,0);
   // TODO: Call CleanUp() from Draw.mqh
   log("********** IcedTea Deinit **********");
   return;
}

//+---------------------------------------------------------------------------+
//| MQL4 Callback Method                                                      |
//+---------------------------------------------------------------------------+
void OnChartEvent(const int id,         // EventID 
                  const long& lparam,   
                  const double& dparam, 
                  const string& sparam) {
   switch(id) {
      case CHARTEVENT_CHART_CHANGE:
         OnChartChange(lparam,dparam,sparam);
         break;
      case CHARTEVENT_KEYDOWN:
         OnKeyPress(lparam,dparam,sparam);
         break;
      case CHARTEVENT_MOUSE_MOVE:
         OnMouseMove(lparam,dparam,sparam);
         break;
      case CHARTEVENT_CLICK:
         break;
      case CHARTEVENT_OBJECT_CLICK:
         break;
      default:
         break;
   }
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
      Swings.DiscoverNodes(NULL,0,pos,1);
   }
   else {
      pos = rates_total - prev_calculated;
      if(pos>=Bars)
         return rates_total;
   }
   
   //log("***OnCalc() start***");
   int ema1_len=ScalePeriod(EMA1_Period);
   int ema2_len=ScalePeriod(EMA2_Period);
   
   // Main buffer loop
   for(int i=pos; i>=0; i--){
      Ema1Buf[i] = iMA(Symbol(),0,ema1_len,0,MODE_EMA,PRICE_CLOSE,i);
      Ema2Buf[i] = iMA(Symbol(),0,ema2_len,0,MODE_EMA,PRICE_CLOSE,i);
   }
   
   if(pos>0) {
      Swings.UpdateNodeLevels();
      Swings.FindAdjacentLinks();
      //UpdateSwingPoints(Symbol(), 0, pos, 1, clrBlack, low, high, Lows, Highs, ChartObjs);
      //UpdateSwingTrends(Symbol(),0,Highs,ChartObjs);
      //UpdateSwingTrends(Symbol(),0,Lows,ChartObjs);
      
       log("***OnCalc updated "+(string)+pos+" bars. prev:"+(string)prev_calculated+", rates_total:"+(string)rates_total+"***");
   }
   return(rates_total);  
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int GetTrend(){
   int idx1=1;
   if(ArraySize(Ema1Buf)<=idx1 || ArraySize(Ema2Buf)<=idx1){
      debuglog("GetTrend() Buffers not initialized. Ema1Buf.len:"+(string)ArraySize(Ema1Buf)+", Ema2Buf.len:"+(string)ArraySize(Ema2Buf));
      return -1;
   }
   // Crossover
   if(Ema1Buf[idx1]>Ema2Buf[idx1]){
      //debuglog("EMA's Bullish ("+DoubleToStr(Ema1Buf[idx1],3)+">"+DoubleToStr(Ema2Buf[idx1],3)+")");
      return 1;
   }
   // Crossunder
   else if(Ema1Buf[idx1]<Ema2Buf[idx1]){
      //debuglog("EMA's Bearish ("+DoubleToStr(Ema1Buf[0],3)+"<"+DoubleToStr(Ema2Buf[idx1],3)+")");
      return -1;
   }
   //log("No trend ("+DoubleToStr(Ema1Buf[idx1],3)+"=="+DoubleToStr(Ema2Buf[idx1],3)+")");
   return 0;
}

//+---------------------------------------------------------------------------+-
//| OnCalculate() has been called already, and indicator destructor/constructor
//| on change of TF.
//+---------------------------------------------------------------------------+
void OnChartChange(long lparam, double dparam, string sparam) {
   // Update HUD
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
   
   Hud.SetItemValue("hud_nodes", Swings.nodes.Count());
   Hud.SetItemValue("hud_node_links", Swings.links.Count());
   
   //debuglog("CHARTEVENT_CHART_CHANGE. lparam:"+(string)lparam+", dparam:"+(string)dparam+", sparam:"+(string)sparam);
}

//+---------------------------------------------------------------------------+-
//| Respond to custom keyboard shortcuts
//+---------------------------------------------------------------------------+
void OnKeyPress(long lparam, double dparam, string sparam){
   // TODO: add KEY_L, to toggle labels on/off
   // TODO: add KEY_D, to toggle drawings on/off
   // TODO: add KEY_H, to toggle labels+drawings on/off
   
   switch(lparam){
      case KEY_S: 
         // Toggle Swing Candle labels
         ShowSwings = ShowSwings ? false : true;
         /*for(int i=0; i<ArraySize(Highs); i++) {
            //Highs[i].Annotate(ShowSwings);
         }
         for(int i=0; i<ArraySize(Lows); i++) {
            //Lows[i].Annotate(ShowSwings);
         }*/
         
         log("ShowSwings:"+(string)ShowSwings);
         break;
      case KEY_L: 
         // Toggle horizontal level lines
         if(ShowLevels==true) {
            // TODO: writeme   
            ShowLevels=false;
         }
         else {
            //DrawFixedRanges(Symbol(), PERIOD_D1, 0, 100, clrRed);
            //DrawFixedRanges(Symbol(), PERIOD_W1, 0, 10, clrBlue);
            //DrawFixedRanges(Symbol(), PERIOD_MN1, 0, 6, clrGreen);
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

//+---------------------------------------------------------------------------+-
//| 
//+---------------------------------------------------------------------------+
void OnMouseMove(long lparam, double dparam, string sparam){
   int bar=CoordsToBar((int)lparam, (int)dparam);
   Hud.SetItemValue("hud_hover_bar",(string)bar);
   DrawCrosshair(lparam, (long)dparam);
   //debuglog("Mouse move. Coords:["+(string)lparam+","+(string)dparam+"]"+", sparam:"+sparam);
}
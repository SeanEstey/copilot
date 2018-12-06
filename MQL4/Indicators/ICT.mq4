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

#define KEY_L     76
#define KEY_S     83
#define MAIN_BUF_NAME   "signal"
#define IMP_HUD_NAME    "impulses_hud"
#define OB_HUD_NAME     "ob_hud"
#define SH_HUD_NAME     "sh_hud"
#define SL_HUD_NAME     "sl_hug"

//---- Inputs
sinput double MinImpulseStdDevs  =3;

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/PriceAction.mqh>
#include <FX/PriceMovement.mqh>
#include <FX/ChartObjects.mqh>

//--- Indicator Buffers
double MainBuf[];

//--- Dynamic pointer arrays (
string ChartObjs[];
Candle* SL[];
Candle* SH[];
Impulse* Impulses[];          
OrderBlock* OrderBlocks[];

//--- Global constants
bool HLinesVisible         = true;
bool SwingLblsVisible      = true;


//+---------------------------------------------------------------------------+
//| Custom indicator initialization function                                  |
//+---------------------------------------------------------------------------+
int OnInit() { 
   ObjectsDeleteAll();   
   IndicatorBuffers(1);
   IndicatorShortName("ICT");
   IndicatorDigits(1);
   SetIndexLabel(0,MAIN_BUF_NAME);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2, clrBlue);
   SetIndexBuffer(0, MainBuf);
   ArraySetAsSeries(MainBuf,true);
   SetIndexDrawBegin(0,1);
   CreateLabel("",SH_HUD_NAME, 5,50);
   CreateLabel("",SL_HUD_NAME, 5,90);
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
 
   // Main buffer loop
   for(int i=0; i<rates_total; i++){
      MainBuf[iBar] = 0;
      
      iBar++;
   }
   
   // Identify/annotate key daily swings
   DrawOverlay(time, high, low);
   FindImpulses(0, 1000, Impulses, MinImpulseStdDevs);
   
   
   return(rates_total);  
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void DrawOverlay(const datetime &time[], const double &high[], const double &low[]) {
   
   DrawSwingLabels(Symbol(), 0, 0, 1000, clrBlack, low, high, SL, SH, ChartObjs);
   
   DrawLevels(Symbol(), PERIOD_D1, 0, 100, clrRed, ChartObjs);
   DrawLevels(Symbol(), PERIOD_W1, 0, 10, clrBlue, ChartObjs);
   DrawLevels(Symbol(), PERIOD_MN1, 0, 6, clrGreen, ChartObjs);
   
   // HUD Stats
   int hh_shift=GetSignificantVisibleSwing(SWING_HIGH, SH);
   ObjectSetString(0,SH_HUD_NAME,OBJPROP_TEXT,
      "Highest Visible SH: "+(string)high[hh_shift]+" ("+TimeToStr(time[hh_shift])+")"); 
   int ll_shift=GetSignificantVisibleSwing(SWING_LOW, SL);
   ObjectSetString(0,SL_HUD_NAME,OBJPROP_TEXT,
      "Lowest Visible SL: "+(string)low[ll_shift]+" ("+TimeToStr(time[ll_shift])+")"); 
     
   // log("Found "+(string)ArraySize(SH)+" SH and "+(string)ArraySize(SL)+" SL.");
   // log("Found "+(string)ArraySize(Impulses)+" impulses!");   
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
            SwingLblsVisible = SwingLblsVisible ? false : true;
            
            for(int i=0; i<ArraySize(SH); i++) {
               SH[i].Annotate(SwingLblsVisible);
            }
            for(int i=0; i<ArraySize(SL); i++) {
               SL[i].Annotate(SwingLblsVisible);
            }
            
            log("SwingLbls toggled:"+(string)SwingLblsVisible);
            break;
         
         // Toggle horizontal level lines
         case KEY_L:
            if(HLinesVisible==true) {
               for(int i=0; i<ArraySize(ChartObjs); i++) {
                  if(ObjectType(ChartObjs[i])==OBJ_TREND)
                     ObjectDelete(ChartObjs[i]);
               }
               HLinesVisible=false;
            }
            else {
               DrawLevels(Symbol(), PERIOD_D1, 0, 100, clrRed, ChartObjs);
               DrawLevels(Symbol(), PERIOD_W1, 0, 10, clrBlue, ChartObjs);
               DrawLevels(Symbol(), PERIOD_MN1, 0, 6, clrGreen, ChartObjs);
               HLinesVisible=true;
            }
            log("HLinesVisible:"+(string)HLinesVisible);
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
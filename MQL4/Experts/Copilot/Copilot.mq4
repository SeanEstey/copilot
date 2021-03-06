//+------------------------------------------------------------------+
//|                                                      Copilot.mq4 |
//+------------------------------------------------------------------+

#define VERSION "1.30"
#property strict

#include "Include/Logging.mqh"
#include "Include/Utility.mqh"
#include "Include/Chart.mqh"
#include "Include/Graph.mqh"
#include "Include/SwingPoints.mqh"
#include "Include/OrderManager.mqh"
#include "Include/Draw.mqh"
#include "Include/Hud.mqh"
#include "Include/Watcher.mqh"
#include "Include/SR.mqh"

#define KEY_L           76
#define KEY_R           82
#define KEY_S           83
#define KEY_ESC         27

enum Algorithms {WEIS_CVD};
enum Modes {COPILOT_MODE, AUTO_MODE};

//--- Globals
Algorithms CurrentAlgo     = WEIS_CVD;
SwingGraph* SG             = NULL;
HUD* Hud                   = NULL;
OrderManager* OM           = NULL;
SRLevelManager* SR         = NULL;
Watcher* W                 = NULL;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   log("\n"+
      "************************************************************************************************************\n"+
      "   __________  ____  ______   ____ ______ \n"+
      "  / ____/ __ \/ __ \/  _/ /  / __ /_  __/ \n"+
      " / /   / / / / /_/ // // /  / / / // /    \n"+
      "/ /___/ /_/ / _____/ // /__/ /_/ // /     \n"+
      "\____/\____/_/   /___/_____\____//_/      \n"+
      "\n"+
      "************************************************************************************************************"
   );
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE,true);
   Hud = new HUD("Copilot v"+VERSION);
   OM = new OrderManager();
   SG = new SwingGraph();
   SG.DiscoverNodes(NULL,0,1000,1);
   SG.UpdateNodeLevels(0); 
   SR = new SRLevelManager();
   SR.Generate(SG);
   W = new Watcher();
   //InitCopilotMode();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   delete OM;
   delete Hud;
   delete SG;
   ObjectDelete(0,V_CROSSHAIR);
   ObjectDelete(0,H_CROSSHAIR); 
   int n=ObjectsDeleteAll();
   log("EA Terminated.");
   log("");
   return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   if(!NewBar())
      return;
   
   log("OnTick()");
   
   SG.UpdateNodeLevels(0);
   SR.Generate(SG);
   
   int tf=PERIOD_H4;
   
   // Add any new levels not currently being watched to watchlist.
   for(int i=0; i<SR.GetLevelCount(); i++){
      SRLevel* sr=SR.GetLevel(i);
      bool has_lvl=false;
       
      for(int j=0; j<W.GetWatchlistCount(); j++){
         TradeSetup* ts=W.GetWatchlist(j);
         
         if(ts.state!=PENDING)
            continue;
         
         for(int c=0; c<ArraySize(ts.conditions); c++){
            if(ts.conditions[c].level==sr.price){
               has_lvl=true;
               break;
            }
         }
      }
      
     if(has_lvl==false){
         Direction dir=Ask>sr.price? BEARISH: BULLISH;
         int otype=Ask>sr.price? OP_SELLLIMIT: OP_BUYLIMIT;
         Condition* c=new Condition(Symbol(),tf,sr.price,BOUNCE,dir);
         Order* o=new Order(-1,Symbol(),otype,1,-1);
         W.Add(new TradeSetup(Symbol(), tf, c,o));
      }
   }
   
   log("OnTick(): Watcher watching "+(string)W.GetWatchlistCount()+" setups.");
   
   W.TickUpdate(OM);
   OM.UpdateClosedPositions(); 
   Hud.Update();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {   
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
         OnMouseClick(lparam,dparam,sparam);
         break;
      case CHARTEVENT_OBJECT_CLICK:
         break;
      default:
         break;
   }
}

//+---------------------------------------------------------------------------+
//| OnCalculate() has been called already, and indicator destructor/constructor
//| on change of TF.
//+---------------------------------------------------------------------------+
void OnChartChange(long lparam, double dparam, string sparam) {
   // Update HUD
   int first = WindowFirstVisibleBar();
   int last = first-WindowBarsPerChart();
   //Hud.SetItemValue("hud_window_bars",(string)(last+2)+"-"+(string)(first+2));
   int hh_shift=iHighest(Symbol(),0,MODE_HIGH,first-last,last);
   int ll_shift=iLowest(Symbol(),0,MODE_LOW,first-last,last);   
   double hh=iHigh(Symbol(),0,hh_shift);
   datetime hh_time=iTime(Symbol(),0,hh_shift);
   double ll=iLow(Symbol(),0,ll_shift);
   datetime ll_time=iTime(Symbol(),0,ll_shift);
}

//+---------------------------------------------------------------------------+
//| Respond to custTM keyboard shortcuts
//+---------------------------------------------------------------------------+
void OnKeyPress(long lparam, double dparam, string sparam){
   switch((int)lparam){
      case KEY_ESC:
         break;
      case KEY_R:
         log("R key input detected.");
         W.watchlist[0].state=VALIDATED;
         break;   
      case KEY_S: 
         break;
      case KEY_L: 
         break;
      default:
         //log("Unmapped keybind:"+(string)lparam); 
         break;
   } 
   ChartRedraw(); 
}

//+---------------------------------------------------------------------------+
//| Draw crosshair, update HUD with relevent info.
//+---------------------------------------------------------------------------+
void OnMouseMove(long lparam, double dparam, string sparam){
   DrawCrosshair(lparam, (long)dparam);
   int m_bar=CoordsToBar((int)lparam, (int)dparam);
   Hud.SetItemValue("hud_hover_bar",(string)m_bar);
   //Hud.SetDialogMsg("Mouse move. Coords:["+(string)lparam+","+(string)dparam+"]");
   
   datetime m_dt;
   double m_price;
   int window=0;
   ChartXYToTimePrice(0,(int)lparam,(int)dparam,window,m_dt,m_price);
}

//+------------------------------------------------------------------+
//| Mouse Input callback                                             |
//+------------------------------------------------------------------+
void OnMouseClick(long lparam, double dparam, string sparam) {
   int subwindow, x=(int)lparam, y=(int)dparam;
   datetime atTime;
   double atPrice;
   ChartXYToTimePrice(0,x,y,subwindow,atTime,atPrice);
}

//+------------------------------------------------------------------+
//| Tester function                                                  |
//| Called at completion of Strategy Tester                          |
//+------------------------------------------------------------------+
double OnTester() {
   log("OnTester()");

   double ret=0.0;
   return(ret);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitAutoMode(){
   // WRITEME: pass in Algo to run in FullAuto mode as arg
}

//+------------------------------------------------------------------+
//| WRITEME: init Watcher and wait for user to create TradeSetups                                                                  |
//+------------------------------------------------------------------+
void InitCopilotMode(){
   W=new Watcher();
   
   string symbol="XTIUSD.pro";
   int tf=PERIOD_H4;
   
   Order* order=new Order(-1,symbol,OP_BUY,1,0);
   Condition* c=new Condition(symbol, tf, 55.214, SFP, BULLISH);
   
   TradeSetup* setups[];
   for(int i=0; i<5; i++){
      ArrayResize(setups, ArraySize(setups)+1);
      setups[ArraySize(setups)-1]=new TradeSetup(symbol, tf, c, order);
   }
   
   for(int i=0; i<5; i++){
      W.Add(setups[i]);
   }
   
   W.Rmv(setups[1]);
   W.Rmv(setups[3]);
   
   log("Copilot Mode Initialized. Watchlist:"+(string)ArraySize(W.watchlist));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CopilotOnTick(){

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AutoOnTick(){
  /*int signal=GetSignal();
   // Close short positions (if any) and open a long.
   if(signal==OPEN_LONG){
      if(OM.GetNumActiveOrders()>0){ 
         Order* order=OM.GetActiveOrder();
         if(order.Type==OP_SELL || order.Type==OP_SELLLIMIT)
            if(OM.ClosePosition(order.Ticket)>-1)
               Hud.SetDialogMsg("Closed Short.",false);
      }
      if(OM.GetNumActiveOrders()==0)
         if(OM.OpenPosition(NULL,OP_BUY)>-1)
            Hud.SetDialogMsg("Opened Long.",false);
   }
   // Close long positions (if any) and open a short.
   else if(signal==OPEN_SHORT){
      if(OM.GetNumActiveOrders()>0){
         Order* order=OM.GetActiveOrder();   
         if(order.Type==OP_BUY || order.Type==OP_BUYLIMIT)
            if(OM.ClosePosition(order.Ticket)>-1)
               Hud.SetDialogMsg("Closed Long.",false);
      }
      if(OM.GetNumActiveOrders()==0)
         if(OM.OpenPosition(NULL,OP_SELL)>-1)
            Hud.SetDialogMsg("Opened Short.",false);
   }
   else if(signal==CLOSE_LONG && OM.GetNumActiveOrders()>0){
      Order* order=OM.GetActiveOrder();
      if(order.Type==OP_BUY || order.Type==OP_BUYLIMIT){
         OM.ClosePosition(order.Ticket);
         Hud.SetDialogMsg("Closed Long.",false);
      }
   }
   else if(signal==CLOSE_SHORT && OM.GetNumActiveOrders()>0){
      Order* order=OM.GetActiveOrder();
      if(order.Type==OP_SELL || order.Type==OP_SELLLIMIT){
         OM.ClosePosition(order.Ticket);
         Hud.SetDialogMsg("Closed Short.",false);
      }
   }*/
   

}
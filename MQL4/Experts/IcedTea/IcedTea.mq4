//+------------------------------------------------------------------+
//|                                                      IcedTea.mq4 |
//+------------------------------------------------------------------+

#define VERSION "1.30"
#property strict

#include "Include/Logging.mqh"
#include "Include/Utility.mqh"
#include "Include/Chart.mqh"
#include "Include/Graph.mqh"
#include "Include/SwingPoints.mqh"
#include "Include/TradeManager.mqh"
#include "Include/Draw.mqh"
#include "Include/Hud.mqh"
#include "Algos/SR.mqh"

#define KEY_L           76
#define KEY_R           82
#define KEY_S           83
#define KEY_ESC         27

enum Algorithms {WEIS_CVD};


//--- Globals
Algorithms CurrentAlgo     = WEIS_CVD;
SwingGraph* Swings         = NULL;
HUD* Hud                   = NULL;
TradeManager* TM           = NULL;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   // Register Event Handlers
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE,true);
   
   Hud = new HUD("IcedTea v"+VERSION);
   Hud.AddItem("acct_name","Account","");
   Hud.AddItem("balance","Balance","");
   Hud.AddItem("free_margin", "Available Margin","");
   Hud.AddItem("unreal_pnl","Unrealized Profit","");
   Hud.AddItem("real_pnl","Realized Profit","");
   Hud.AddItem("ntrades","Active Trades","");
   Hud.AddItem("hud_hover_bar","Hover Bar","");
   //Hud.AddItem("hud_window_bars","Bars","");
   //Hud.AddItem("hud_highest_high","Highest High","");
   //Hud.AddItem("hud_lowest_low", "Lowest Low", "");
   //Hud.AddItem("hud_trend", "Swing Trend", "");
   //Hud.AddItem("hud_nodes", "Swing Nodes", "");
   //Hud.AddItem("hud_node_links", "Node Links", "");
   Hud.SetItemValue("acct_name",AccountInfoString(ACCOUNT_NAME));
   Hud.SetItemValue("balance",DoubleToStr(AccountInfoDouble(ACCOUNT_BALANCE),2));
   Hud.SetItemValue("free_margin",DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2));
   Hud.SetDialogMsg("Hud created.");
   
   TM = new TradeManager();
   TM.GetAcctStats();
   TM.GetAssetStats();
   
   Swings = new SwingGraph();
   Swings.DiscoverNodes(NULL,0,1000,1);
   Swings.UpdateNodeLevels(0); 
   GenerateSR(Swings);  
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log(deinit_reason(reason));
   delete TM;
   delete Hud;
   delete Swings;
   ObjectDelete(0,V_CROSSHAIR);
   ObjectDelete(0,H_CROSSHAIR); 
   int n=ObjectsDeleteAll();
   log("EA Terminated.");
   log("");
  
   //log("********** IcedTea Deinit. Deleted "+(string)n+" objects. **********");
   return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   if(!NewBar())
      return;
   
   Swings.UpdateNodeLevels(0);
   
   int signal=GetSignal();
   /*
   // Close short positions (if any) and open a long.
   if(signal==OPEN_LONG){
      if(TM.GetNumActiveOrders()>0){ 
         Order* order=TM.GetActiveOrder();
         if(order.Type==OP_SELL || order.Type==OP_SELLLIMIT)
            if(TM.ClosePosition(order.Ticket)>-1)
               Hud.SetDialogMsg("Closed Short.",false);
      }
      if(TM.GetNumActiveOrders()==0)
         if(TM.OpenPosition(NULL,OP_BUY)>-1)
            Hud.SetDialogMsg("Opened Long.",false);
   }
   // Close long positions (if any) and open a short.
   else if(signal==OPEN_SHORT){
      if(TM.GetNumActiveOrders()>0){
         Order* order=TM.GetActiveOrder();   
         if(order.Type==OP_BUY || order.Type==OP_BUYLIMIT)
            if(TM.ClosePosition(order.Ticket)>-1)
               Hud.SetDialogMsg("Closed Long.",false);
      }
      if(TM.GetNumActiveOrders()==0)
         if(TM.OpenPosition(NULL,OP_SELL)>-1)
            Hud.SetDialogMsg("Opened Short.",false);
   }
   else if(signal==CLOSE_LONG && TM.GetNumActiveOrders()>0){
      Order* order=TM.GetActiveOrder();
      if(order.Type==OP_BUY || order.Type==OP_BUYLIMIT){
         TM.ClosePosition(order.Ticket);
         Hud.SetDialogMsg("Closed Long.",false);
      }
   }
   else if(signal==CLOSE_SHORT && TM.GetNumActiveOrders()>0){
      Order* order=TM.GetActiveOrder();
      if(order.Type==OP_SELL || order.Type==OP_SELLLIMIT){
         TM.ClosePosition(order.Ticket);
         Hud.SetDialogMsg("Closed Short.",false);
      }
   }*/
   
   
   TM.UpdateClosedPositions(); 
   Hud.SetItemValue("free_margin",DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2));
   Hud.SetItemValue("balance",DoubleToStr(AccountInfoDouble(ACCOUNT_BALANCE),2));
   Hud.SetItemValue("unreal_pnl",(string)TM.GetTotalProfit(true));
   Hud.SetItemValue("real_pnl",(string)TM.GetTotalProfit(false));
   Hud.SetItemValue("ntrades",(string)TM.GetNumActiveOrders());
   
   //log("OnTick(): "+(string)TM.GetNumActiveOrders()+" open position(s), "+
   //   (string)TM.GetTotalProfit()+" Unrealized PNL, "+
   //   (string)TM.GetTotalProfit(false)+" Realized PNL.");
}

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester() {
   double ret=0.0;
   return(ret);
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
         break;   
      case KEY_S: 
         break;
      case KEY_L: 
         break;
      default:
         //log("Unmapped key:"+(string)lparam); 
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
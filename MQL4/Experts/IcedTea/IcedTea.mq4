//+------------------------------------------------------------------+
//|                                                      IcedTea.mq4 |
//+------------------------------------------------------------------+

#define VERSION "1.20"
#property strict

#include "Include/Logging.mqh"
#include "Include/Utility.mqh"
#include "Include/Chart.mqh"
#include "Include/Graph.mqh"
#include "Include/Orders.mqh"
#include "Include/SwingPoints.mqh"
#include "Include/Draw.mqh"
#include "Include/Hud.mqh"
#include "Algos/WeisCVD.mqh"


#define KEY_L           76
#define KEY_R           82
#define KEY_S           83
#define KEY_ESC         27

enum Algorithms {WEIS_CVD};


//--- Globals
Algorithms CurrentAlgo     = WEIS_CVD;
HUD* Hud                   = NULL;
SwingGraph* Swings         = NULL;
bool ShowLevels            = false;
bool ShowSwings            = true;
TradeManager* TM           = NULL;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   log("********** IcedTea Initializing **********");
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
   Hud.AddItem("hud_window_bars","Bars","");
   Hud.AddItem("hud_highest_high","Highest High","");
   Hud.AddItem("hud_lowest_low", "Lowest Low", "");
   Hud.AddItem("hud_trend", "Swing Trend", "");
   Hud.AddItem("hud_nodes", "Swing Nodes", "");
   Hud.AddItem("hud_node_links", "Node Links", "");
   Hud.SetItemValue("acct_name",AccountInfoString(ACCOUNT_NAME));
   Hud.SetItemValue("balance",DoubleToStr(AccountInfoDouble(ACCOUNT_BALANCE),2));
   Hud.SetItemValue("free_margin",DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2));
   Hud.SetDialogMsg("Hud created.");
   TM = new TradeManager();
   TM.GetAcctStats();
   log("********** All systems check. **********");
   Hud.SetDialogMsg("All systems check.");
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
   log("********** IcedTea Deinit. Deleted "+(string)n+" objects. **********");
   return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   if(!NewBar())
      return;
   
   int signal=GetSignal();
   
   // Buy signal
   if(signal==1){
      // If currently short, close position.
      if(TM.GetNumActiveOrders()>0){
         Order* order=TM.GetActiveOrder();
         if(order.Type==OP_SELL || order.Type==OP_SELLLIMIT)
            TM.ClosePosition(order.Ticket);
      }
      // Open long position
      if(TM.GetNumActiveOrders()==0)
         TM.OpenPosition(NULL,OP_BUY);
   }
   // Sell signal
   else if(signal==-1){
      // If currently long, close position
      if(TM.GetNumActiveOrders()>0){
         Order* order=TM.GetActiveOrder();
         if(order.Type==OP_BUY || order.Type==OP_BUYLIMIT)
            TM.ClosePosition(order.Ticket);
      }
      // Open short position
      if(TM.GetNumActiveOrders()==0)
         TM.OpenPosition(NULL,OP_SELL);
   }
      
   Hud.SetItemValue("free_margin",DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2));
   Hud.SetItemValue("balance",DoubleToStr(AccountInfoDouble(ACCOUNT_BALANCE),2));
   Hud.SetItemValue("unreal_pnl",TM.GetTotalProfit(true));
   Hud.SetItemValue("real_pnl",TM.GetTotalProfit(false));
   Hud.SetItemValue("ntrades",TM.GetNumActiveOrders());
   
   log("OnTick(): "+(string)TM.GetNumActiveOrders()+" open position(s), "+
      (string)TM.GetTotalProfit()+" Unrealized PNL, "+
      (string)TM.GetTotalProfit(false)+" Realized PNL.");
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
   Hud.SetItemValue("hud_window_bars",(string)(last+2)+"-"+(string)(first+2));
   int hh_shift=iHighest(Symbol(),0,MODE_HIGH,first-last,last);
   int ll_shift=iLowest(Symbol(),0,MODE_LOW,first-last,last);   
   double hh=iHigh(Symbol(),0,hh_shift);
   datetime hh_time=iTime(Symbol(),0,hh_shift);
   double ll=iLow(Symbol(),0,ll_shift);
   datetime ll_time=iTime(Symbol(),0,ll_shift);
   Hud.SetItemValue("hud_lowest_low", DoubleToStr(ll,3)+" [Bar "+(string)(ll_shift+2)+"]"); 
   Hud.SetItemValue("hud_highest_high", DoubleToStr(hh,3)+" [Bar "+(string)(hh_shift+2)+"]");
   //Hud.SetItemValue("hud_nodes", (string)Swings.NodeCount());
   //Hud.SetItemValue("hud_node_links", (string)Swings.RelationshipCount());
   GetTrend();
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
   Hud.SetDialogMsg("Mouse move. Coords:["+(string)lparam+","+(string)dparam+"]");
   
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


//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int GetTrend(){
   /*SwingRelationship* link1=Swings.GetRelationshipByIndex(Swings.RelationshipCount()-1);
   SwingRelationship* link2=Swings.GetRelationshipByIndex(Swings.RelationshipCount()-2);
   
   MarketStructure d1=link1.Desc;
   MarketStructure d2=link2.Desc;
   
   if(d1==HIGHER_HIGH || d1==HIGHER_LOW){
      if(d2==HIGHER_HIGH || d2==HIGHER_LOW)
         Hud.SetItemValue("hud_trend", "Bullish");
      else
         Hud.SetItemValue("hud_trend", "Neutral");
   }
   else if(d1==LOWER_HIGH || d1==LOWER_LOW) {
      if(d2==LOWER_HIGH || d2==LOWER_LOW)
         Hud.SetItemValue("hud_trend", "Bearish");
      else
         Hud.SetItemValue("hud_trend", "Neutral");
   }
   */
 
   //log("Last 2 SwingLink Descriptions:"+
   //   link1.ToString()+" (Lvl-"+(string)((SwingPoint*)link1.n2).Level+"), "+
   //   link2.ToString()+" (Lvl-"+(string)((SwingPoint*)link2.n2).Level+")");
   return 0;
}

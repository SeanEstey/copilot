//+------------------------------------------------------------------+
//|                                                      wingman.mq4 |
//|                                 Copyright 2018, Wing Enterprises |
//|                                         https://www.wingcorp.com |
//+------------------------------------------------------------------+
#include <utility.mqh>
#property copyright "Copyright 2018, Wing Enterprises"
#property link      "https://www.wingcorp.com"
#property version   "1.00"
#property strict
#define MAGICMA  20131111

//--- Inputs
input bool   DEBUG            = true;
input double Lots             = 1.0;
input int    TakeProfit       = 75;    
input int    StopLoss         = 25;
input int    RSILen           = 14;
input int    KLen             = 10;
input int    DLen             = 3;
input int    Slowing          = 2;
input int    StochOB          = 90;
input int    StochOS          = 10;
input int    FishLen          = 10;
input double FishBands        = 1.0;

//--- Globals
int nTrades=0;
int nPositions=0;
int nStops=0;
int nTakeProfit=0;
string ntrades_lbl = "trades";
string npos_lbl = "positions";

string OrderTypes[6] = {"BUY", "SELL", "BUYLIMIT", "BUYSTOP", "SELLLIMIT", "SELLSTOP"};
int SLOrders[];
int TPOrders[];
int Orders[];

double GetLots() {return Lots;}
int CalculateCurrentOrders(string symbol) {return 1;}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
int OnInit() {
   string text = "Wingman!";

   ObjectCreate(0,ntrades_lbl,OBJ_LABEL,0,0,0);
   ObjectSetString(0,ntrades_lbl,OBJPROP_TEXT,"Trades: 0");
   ObjectSetInteger(0,ntrades_lbl,OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,ntrades_lbl,OBJPROP_YDISTANCE,50);
   ObjectSetInteger(0,ntrades_lbl,OBJPROP_COLOR,clrBlack);
   
   ObjectCreate(0,npos_lbl,OBJ_LABEL,0,0,0);
   ObjectSetString(0,npos_lbl,OBJPROP_TEXT,"Positions: 0");
   ObjectSetInteger(0,npos_lbl,OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,npos_lbl,OBJPROP_YDISTANCE,75);
   ObjectSetInteger(0,npos_lbl,OBJPROP_COLOR,clrBlack);
   
   ArrayResize(SLOrders,1);
   ArrayResize(TPOrders,1);
   ArrayResize(Orders,1);
   
   log("********** Wingman Initialized **********");
   return(INIT_SUCCEEDED);
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectDelete(ntrades_lbl); 
   ObjectDelete(npos_lbl); 
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
double OnTester() {
   log("********** Wingman Test Complete **********");
   
   log("********** Test Summary **********");
   log((string)nTrades+" total trades made.");
   log((string)nPositions+" positions open.");
   log((string)nStops+" orders hit StopLoss.");
   log((string)nTakeProfit+" orders hit TakeProfit.");
   log("SLOrders.length:"+ArraySize(SLOrders));
   log("TPOrders.length:"+ArraySize(TPOrders));
   log("*******************************************");
   
   
   log("Orders: "+printArray(Orders));
   log("SLOrders: "+printArray(SLOrders));
   log("TPOrders: "+printArray(TPOrders));
   
   return 0.0;
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
void CheckClosedOrders() {
   int ticket;
   for(int i=0; i<ArraySize(Orders); i++) {
      ticket=Orders[i];
      
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY)) { 
         //log("Error retrieving order "+ticket+"\n"+
         //   "Symbol:"+OrderSymbol()+", Comment:"+OrderComment());
         continue;
      }
      // Not our order. Skip.
      else if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
      
      // Check if StopLoss was hit 
      if(OrderStopLoss()==OrderClosePrice() || StringFind(OrderComment(), "[sl]", 0)!=-1){  
         if(SLOrders[ArrayBsearch(SLOrders, ticket)] != ticket) {
            log("Order #"+ticket+" hit TP!");
            ArrayResize(SLOrders,ArraySize(SLOrders)+1);
            SLOrders[ArraySize(SLOrders)-1] = ticket;
            ArraySort(SLOrders, WHOLE_ARRAY, 0, MODE_ASCEND);
            ObjCreate((string)ticket+"_SL",Symbol(),OBJ_ARROW_STOP,0,clrRed,ANCHOR_BOTTOM);
            nStops++;
            nPositions--;
         }
      }
      // Check if TakeProfit was hit
      else if(OrderProfit()==OrderClosePrice() || StringFind(OrderComment(), "[tp]", 0)!=-1){
         if(TPOrders[ArrayBsearch(TPOrders, ticket)] != ticket) {
            log("Order #"+ticket+" hit TP!");
            ArrayResize(TPOrders,ArraySize(TPOrders)+1);
            TPOrders[ArraySize(TPOrders)-1] = ticket;
            ArraySort(TPOrders, WHOLE_ARRAY, 0, MODE_ASCEND);
            ObjCreate((string)ticket+"_TP",Symbol(),OBJ_ARROW_CHECK,0,clrGreen,ANCHOR_TOP);
            nTakeProfit++;
            nPositions--;   
         }
      }
   }
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
void UpdateOpenPendingOrders() {
   int res, action;
   
   for(int i=0; i<OrdersTotal(); i++) {
      // Load next open/pending order
      bool is_selected = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);      
      if(!is_selected) {
         log("Could not retrieve order. "+err_msg());
         continue;
      }     
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA) {
         //log("Unrecognized order. OrderInfo: "+OrderComment());
         continue;
      }
         
      action = UpdatePosition();
      
      if(action==0)
         continue;
      else if(action == 1) {
         res=OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrBlue);
         ObjCreate((string)OrderTicket()+"_close", Symbol(), OBJ_ARROW_UP,
            0, clrRed, ANCHOR_TOP);
      }
      else if(action == -1) {
         res=OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed);
         ObjCreate((string)OrderTicket()+"_close", Symbol(), OBJ_ARROW_DOWN,
            0, clrBlue, ANCHOR_BOTTOM);
      }
      
      if(res != 1)
         log("Error closing order "+OrderTicket()+", Reason: "+err_msg());
      else {
         log("Closed "+OrderTypes[OrderType()]+" order #"+OrderTicket()+
            ", Reason: StochRSI reset.");
         nTrades++;
         nPositions--;
      }
   }
}

//+---------------------------------------------------------------------------+
//| Evaluate new positions
//+---------------------------------------------------------------------------+
void CreateNewOrders() {
   if(!NewBar())
      return;
      
   int oid, type;
   double TP=0.0, SL=0.0, price=0.0;
   int signal = GenerateSignal();
   
   if(signal==0) {
      ObjectSetString(0,ntrades_lbl,OBJPROP_TEXT,"Trades:"+(string)nTrades);
      ObjectSetString(0,npos_lbl,OBJPROP_TEXT,"Positions:"+(string)nPositions);
      return;
   }
   else if(signal==1){  // Buy   
      type=OP_BUY;
      price = Bid;
      TP = Bid + TakeProfit*Point*10;   //0.00001 * 10 = 0.0001
      SL = Bid - StopLoss*Point*10;
      oid = OrderSend(Symbol(),type,GetLots(),Ask,3,SL,TP,"",MAGICMA,0,clrBlue);
      ObjCreate((string)oid+"_open", Symbol(), OBJ_ARROW_UP, 0, clrBlue, ANCHOR_TOP);
   }
   else if(signal==-1){  // Sell
      type=OP_SELL;
      price = Ask;
      TP = Ask - TakeProfit*Point*10;   //0.00001 * 10 = 0.0001
      SL = Ask + StopLoss*Point*10;
      oid = OrderSend(Symbol(),type,GetLots(),Bid,3,SL,TP,"",MAGICMA,0,clrRed);
      ObjCreate((string)oid+"_open", Symbol(), OBJ_ARROW_DOWN, 0, clrRed, ANCHOR_BOTTOM);
   }
   
   if(oid == -1 || oid == 0) { 
      log("Error creating "+OrderType()+" order. Reason: "+err_msg()+
          "\nOrder Symbol:"+Symbol()+", minStopLevel:"+(string)MarketInfo(Symbol(), MODE_STOPLEVEL) + 
          ", TP:"+(string)TP+", SL:"+(string)SL);
      return;
   }
   
   Orders[ArraySize(Orders)-1] = oid;
   ArraySort(Orders, WHOLE_ARRAY, 0, MODE_ASCEND);
   ArrayResize(Orders,ArraySize(Orders)+1);
   
   nTrades++;
   nPositions++;
   log(OrderTypes[type]+" order #"+oid+", Price:"+(string)price+", TP:"+(string)TP+", SL:"+(string)SL);
}
  
//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnTick() {     
   CheckClosedOrders();
   UpdateOpenPendingOrders();   
   CreateNewOrders();

   ObjectSetString(0,ntrades_lbl,OBJPROP_TEXT,"Trades:"+(string)nTrades);
   ObjectSetString(0,npos_lbl,OBJPROP_TEXT,"Positions:"+(string)nPositions);
   return;
}


//+----------------------------------------------------------------------------+
//|**************************** SIGNAL ALGOS **********************************|
//+----------------------------------------------------------------------------+

//+----------------------------------------------------------------------------+
//| Look for confluence between Stochastic RSI oversold/overbought conditions
//| and Fisher Transform in extreme range.
//| Returns value: 1 for buy signal, -1 for sell signal, 0 otherwise
//+----------------------------------------------------------------------------+
int GenerateSignal() {   
   
   // Look for overbought/oversold confluence w/ StochRSI and Fisher Transform
   
   double s1 = iCustom(NULL,0,"StochRSI",
      RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,0);
   double s1_prev = iCustom(NULL,0,"StochRSI",
      RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,1);
   double s2 = iCustom(NULL,0,"StochRSI",
      RSILen,KLen,DLen,Slowing,StochOB,StochOS,1,Slowing);
   double s2_prev = iCustom(NULL,0,"StochRSI",
      RSILen,KLen,DLen,Slowing,StochOB,StochOS,1,Slowing+1);
   bool sob_trig = s2<StochOB && s2_prev>=StochOB && s2<s1 ? true : false;
   bool sos_trig = s2>StochOS && s2_prev<=StochOS && s2>s1 ? true : false;
         
   double f1 =  iCustom(NULL,0,"FisherTransform",
      FishLen,FishBands, 0,0);
   double f2 =  iCustom(NULL,0,"FisherTransform",
      FishLen,FishBands, 1,0);
   bool fob_trig = f1>FishBands && f2>FishBands ? true : false;
   bool fos_trig = f1<FishBands*-1 && f2<FishBands*-1 ? true : false;
   
   // Get HTF trend confluence
   int d1_ema_fast_len = 10;
   int d1_ema_slow_len = 20;
   int fast_len = (PERIOD_D1/Period()) * d1_ema_fast_len;
   int slow_len = (PERIOD_D1/Period()) * d1_ema_slow_len;
   //log("Current TF:"+Period()+", EMA_FAST:"+fast_len+", EMA_SLOW:"+slow_len);
   // Args 3-5: Period, Shift, Method
   double ema1 = iCustom(NULL,0,"Custom Moving Averages", fast_len, 0, MODE_EMA,0,0); 
   double ema2 = iCustom(NULL,0,"Custom Moving Averages", slow_len, 0, MODE_EMA,0,0);
   bool uptrend = ema1>ema2 ? true : false;
   bool downtrend = ema1<ema2 ? true : false;
   
   bool golong = sos_trig && fos_trig && uptrend ? true : false;
   bool goshort = sob_trig && fob_trig && downtrend ? true : false;
   
   if(golong || goshort) {
      log("Trade signal. Uptrend:"+uptrend+", Downtrend:"+downtrend+
         ", EMA1:"+DoubleToStr(ema1,2)+", EMA2:"+DoubleToStr(ema2,2));
   }
   return golong ? 1 : goshort ? -1 : 0;
}

//+----------------------------------------------------------------------------+
//| Close/hold position.
//| Returns: 1 for close short, -1 for close long, 0 for hold.
//+----------------------------------------------------------------------------+
int UpdatePosition() {      
   double storsi = iCustom(NULL,0,"StochRSI",
      RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,0);
   double storsi_prev = iCustom(NULL,0,"StochRSI",
      RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,1);
   double stosig_prev = iCustom(NULL,0,"StochRSI",
      RSILen,KLen,DLen,Slowing,StochOB,StochOS,1,Slowing+1);
   
   // Close short when StochRSI moves above Overbought line
   if(OrderType()==OP_SELL && storsi_prev<=StochOS && storsi>StochOS)
      return 1;
   // Close long when StochRSI moves below Oversold line
   else if(OrderType()==OP_BUY && storsi_prev>=StochOB && storsi<StochOB)
      return -1;
   else
      return 0;     
}

//+-----------------------------------------------------------------------------+
//| 
//+-----------------------------------------------------------------------------+
int GetHTFTrend() { 
   int d1_ema_fast_len = 10;
   int d1_ema_slow_len = 20;
   int fast_len = (PERIOD_D1/Period()) * d1_ema_fast_len;
   int slow_len = (PERIOD_D1/Period()) * d1_ema_slow_len;
   
   log("Current TF:"+Period()+", EMA_FAST:"+fast_len+", EMA_SLOW:"+slow_len);
   
   // Args 3-5: Period, Shift, Method
   double ema1 = iCustom(NULL,0,"Custom Moving Averages", fast_len, 0, MODE_EMA,0,0);
   // Shift 1 bar left
   double ema1_prev = iCustom(NULL,0,"Custom Moving Averages", fast_len, 0, MODE_EMA,0,1);
   double ema2 = iCustom(NULL,0,"Custom Moving Averages", slow_len, 0, MODE_EMA,0,1);
   double ema2_prev = iCustom(NULL,0,"Custom Moving Averages", slow_len, 0, MODE_EMA,0,1);
   
   if(ema1>ema2) {
      log("Uptrend. FAST_EMA:"+ema1+", SLOW_EMA:"+ema2);
      return -1;
   }
   else if(ema1<ema2) {
      log("Downtrend. FAST_EMA:"+ema1+", SLOW_EMA:"+ema2);
      return 1;
   }
   else {
      log("No trend. FAST_EMA:"+ema1+", SLOW_EMA:"+ema2);
      return 0;
   }
}


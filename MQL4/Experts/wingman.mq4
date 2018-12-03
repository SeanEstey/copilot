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
input int    _RSILen          = 10;
input int    _KLen            = 10;
input int    _DLen            = 2;
input int    _Slowing         = 2;
input int    _StochOB         = 91;
input int    _StochOS         = 11;
input int    _FishLen         = 10;         
input double _FishBands       = 1.0;        

// Number of bars to include in calculation
// Absolute value of upper and lower bands

double Lots             = 1.0;
int    TakeProfit       = 75;   
int    StopLoss         = 25;

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
string ObjList[];

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
   log("Wingman Deinit. ObjList.size:"+(string)ArraySize(ObjList)+", IsTesting:"+IsTesting());
   log("ObjList:"+strArrayToStr(ObjList));
   
   if(!IsTesting()) {
      ObjectDelete(ntrades_lbl); 
      ObjectDelete(npos_lbl); 
      ObjectsDeleteAll();
   }
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
   log("*******************************************");
   log("Orders: "+intArrayToStr(Orders));
   log("SLOrders: "+intArrayToStr(SLOrders));
   log("TPOrders: "+intArrayToStr(TPOrders));
   return 0.0;
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnTick() {
   if(!NewBar())
      return;
      
   CheckClosedOrders();
   UpdateOpenPendingOrders();   
   CreateNewOrders();

   ObjectSetString(0,ntrades_lbl,OBJPROP_TEXT,"Trades:"+(string)nTrades);
   ObjectSetString(0,npos_lbl,OBJPROP_TEXT,"Positions:"+(string)nPositions);
   return;
}


//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
void CheckClosedOrders() {
   int ticket;
   for(int i=0; i<ArraySize(Orders); i++) {
      ticket=Orders[i];
      
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         continue;
      else if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
      
      // Check if StopLoss was hit 
      if(OrderStopLoss()==OrderClosePrice() || StringFind(OrderComment(), "[sl]", 0)!=-1){  
         if(SLOrders[ArrayBsearch(SLOrders, ticket)] != ticket) {
            log("Order #"+(string)ticket+" hit SL!");
            CreateArrow((string)ticket+"_SL", Symbol(), OBJ_ARROW_STOP,
               iBarShift(Symbol(),0,OrderCloseTime()), clrRed, ObjList);
            ArrayResize(SLOrders,ArraySize(SLOrders)+1);
            SLOrders[ArraySize(SLOrders)-1] = ticket;
            ArraySort(SLOrders, WHOLE_ARRAY, 0, MODE_ASCEND);
            
            nStops++;
            nPositions--;
         }
      }
      // Check if TakeProfit was hit
      else if(OrderProfit()==OrderClosePrice() || StringFind(OrderComment(), "[tp]", 0)!=-1){
         if(TPOrders[ArrayBsearch(TPOrders, ticket)] != ticket) {
            CreateArrow((string)ticket+"_TP",Symbol(),OBJ_ARROW_CHECK,
               iBarShift(Symbol(),0,OrderCloseTime()), clrGreen, ObjList);
            ArrayResize(TPOrders,ArraySize(TPOrders)+1);
            TPOrders[ArraySize(TPOrders)-1] = ticket;
            ArraySort(TPOrders, WHOLE_ARRAY, 0, MODE_ASCEND);
            
            nTakeProfit++;
            nPositions--;   
            
            log("Order #"+(string)ticket+" hit TP!");
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
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
         
      action = GetExitSignal();
      
      if(action==0)
         continue;
      else if(action == 1) {
         res=OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrBlue);
         CreateArrow((string)OrderTicket()+"_close", Symbol(), OBJ_ARROW_UP,0,clrRed, ObjList);
      }
      else if(action == -1) {
         res=OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed);
         CreateArrow((string)OrderTicket()+"_close", Symbol(), OBJ_ARROW_DOWN,0, clrBlue, ObjList);
      }
      
      if(res != 1)
         log("Error closing order "+(string)OrderTicket()+", Reason: "+err_msg());
      else {
         log("Closed "+OrderTypes[OrderType()]+" order #"+(string)OrderTicket()+
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
   int oid, type;
   double TP=0.0, SL=0.0, price=0.0;
   int signal = GetEntrySignal();
   
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
      CreateArrow((string)oid+"_open", Symbol(), OBJ_ARROW_UP, 0, clrBlue, ObjList);
      log("ObjList.size:"+(string)ArraySize(ObjList));
   }
   else if(signal==-1){  // Sell
      type=OP_SELL;
      price = Ask;
      TP = Ask - TakeProfit*Point*10;   //0.00001 * 10 = 0.0001
      SL = Ask + StopLoss*Point*10;
      oid = OrderSend(Symbol(),type,GetLots(),Bid,3,SL,TP,"",MAGICMA,0,clrRed);
      CreateArrow((string)oid+"_open", Symbol(), OBJ_ARROW_DOWN, 0, clrRed, ObjList);
   }
   else {
      log("Error creating "+(string)OrderType()+" order. Reason: "+err_msg()+
          "\nOrder Symbol:"+Symbol()+", minStopLevel:"+(string)MarketInfo(Symbol(), MODE_STOPLEVEL) + 
          ", TP:"+(string)TP+", SL:"+(string)SL);
      return;
   }
   
   Orders[ArraySize(Orders)-1] = oid;
   ArraySort(Orders, WHOLE_ARRAY, 0, MODE_ASCEND);
   ArrayResize(Orders,ArraySize(Orders)+1);
   
   nTrades++;
   nPositions++;
   log(OrderTypes[type]+" order #"+(string)oid+", Price:"+(string)price+", TP:"+(string)TP+", SL:"+(string)SL);
}
  


//+----------------------------------------------------------------------------+
//| Look for confluence between Stochastic RSI oversold/overbought conditions
//| and Fisher Transform in extreme range.
//| Returns value: 1 for buy signal, -1 for sell signal, 0 otherwise
//+----------------------------------------------------------------------------+
int GetEntrySignal() {      
   
   /***** Primary signals *****/
   
   double s1=iCustom(Symbol(),0,"StochRSI",_RSILen,_KLen,_DLen,_Slowing,_StochOB,_StochOS,0,0);
   double s1_prev=iCustom(Symbol(),0,"StochRSI",_RSILen,_KLen,_DLen,_Slowing,_StochOB,_StochOS,0,1);
   double s2=iCustom(Symbol(),0,"StochRSI",_RSILen,_KLen,_DLen,_Slowing,_StochOB,_StochOS,1,2);
   double s2_prev=iCustom(Symbol(),0,"StochRSI",_RSILen,_KLen,_DLen,_Slowing,_StochOB,_StochOS,1,2+1);
   bool sob_trig=s2<_StochOB && s2_prev>=_StochOB && s2<s1 ? true : false;
   bool sos_trig=s2>_StochOS && s2_prev<=_StochOS && s2>s1 ? true : false;           
   double f1=iCustom(Symbol(),0,"FisherTransform",_FishLen,_FishBands,0,0);
   double f2=iCustom(Symbol(),0,"FisherTransform",_FishLen,_FishBands,1,0);
   bool fob_trig=f1>_FishBands && f2>_FishBands ? true : false;
   bool fos_trig=f1<_FishBands*-1 && f2<_FishBands*-1 ? true : false;
   
   /***** HTF Trend Confluence *****/
   
   int d1_ema_fast_len = 10;
   int d1_ema_slow_len = 20;
   int fast_len = (PERIOD_D1/Period()) * d1_ema_fast_len;
   int slow_len = (PERIOD_D1/Period()) * d1_ema_slow_len;
   double ema1 = iCustom(NULL,0,"Custom Moving Averages", fast_len, 0, MODE_EMA,0,0); 
   double ema2 = iCustom(NULL,0,"Custom Moving Averages", slow_len, 0, MODE_EMA,0,0);
   bool uptrend = ema1>ema2 ? true : false;
   bool downtrend = ema1<ema2 ? true : false;
   
   /*double  iADX(
   string       symbol,        // symbol
   int          timeframe,     // timeframe
   int          period,        // averaging period
   int          applied_price, // applied price
   int          mode,          // line index
   int          shift          // shift
   );*/
   
   bool golong = sos_trig && fos_trig && uptrend ? true : false;
   bool goshort = sob_trig && fob_trig && downtrend ? true : false;
   
   if(golong || goshort) {
      log("Trade signal. Uptrend:"+(string)uptrend+", Downtrend:"+(string)downtrend+
         ", EMA1:"+DoubleToStr(ema1,2)+", EMA2:"+DoubleToStr(ema2,2));
   }
   return golong ? 1 : goshort ? -1 : 0;
}

//+----------------------------------------------------------------------------+
//| Close/hold position.
//| Returns: 1 for close short, -1 for close long, 0 for hold.
//+----------------------------------------------------------------------------+
int GetExitSignal() {      
   double storsi = iCustom(Symbol(),0,"StochRSI",_RSILen,_KLen,_DLen,_Slowing,_StochOB,_StochOS,0,0);
   double storsi_prev = iCustom(Symbol(),0,"StochRSI",_RSILen,_KLen,_DLen,_Slowing,_StochOB,_StochOS,0,1);
   double stosig_prev = iCustom(Symbol(),0,"StochRSI",_RSILen,_KLen,_DLen,_Slowing,_StochOB,_StochOS,1,2+1);
   
   // Close short when StochRSI moves above Overbought line
   if(OrderType()==OP_SELL && storsi_prev<=_StochOS && storsi>_StochOS)
      return 1;
   // Close long when StochRSI moves below Oversold line
   else if(OrderType()==OP_BUY && storsi_prev>=_StochOB && storsi<_StochOB)
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
   
   log("Current TF:"+(string)Period()+", EMA_FAST:"+(string)fast_len+", EMA_SLOW:"+(string)slow_len);
   
   // Args 3-5: Period, Shift, Method
   double ema1 = iCustom(NULL,0,"Custom Moving Averages", fast_len, 0, MODE_EMA,0,0);
   // Shift 1 bar left
   double ema1_prev = iCustom(NULL,0,"Custom Moving Averages", fast_len, 0, MODE_EMA,0,1);
   double ema2 = iCustom(NULL,0,"Custom Moving Averages", slow_len, 0, MODE_EMA,0,1);
   double ema2_prev = iCustom(NULL,0,"Custom Moving Averages", slow_len, 0, MODE_EMA,0,1);
   
   if(ema1>ema2) {
      log("Uptrend. FAST_EMA:"+(string)ema1+", SLOW_EMA:"+(string)ema2);
      return -1;
   }
   else if(ema1<ema2) {
      log("Downtrend. FAST_EMA:"+(string)ema1+", SLOW_EMA:"+(string)ema2);
      return 1;
   }
   else {
      log("No trend. FAST_EMA:"+(string)ema1+", SLOW_EMA:"+(string)ema2);
      return 0;
   }
}


//+------------------------------------------------------------------+
//|                                                  crackerjack.mq4 |
//|                           Copyright 2018, Crackajack Enterprises |
//|                                       https://www.crackajack.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Crackajack Enterprises"
#property link      "https://www.cracka.com"
#property version   "1.00"
#property strict
#define MAGICMA  20131111

//--- Inputs
input int    RSILen           = 10;
input int    KLen             = 10;
input int    DLen             = 2;
input int    Slowing          = 2;
input int    StochOB          = 91;
input int    StochOS          = 11;
input double Lots             = 0.1;
input int    TakeProfit       = 75;   
input int    StopLoss         = 25;
input int    ADXPeriod        = 14;
input int    ADXRangeLvl      = 25;


#include <utility.mqh>

//--- Globals
string indicator_name="Crackajack";
int nTrades=0;
int nPositions=0;
int nStops=0;
int nTakeProfit=0;
int OrderDelay=0;
datetime LastOrderDt=-1;
int SLOrders[];
int TPOrders[];
int Orders[];
string ObjList[];
string OrderTypes[6] = {"BUY", "SELL", "BUYLIMIT", "BUYSTOP", "SELLLIMIT", "SELLSTOP"};

double GetLots() {return Lots;}
int CalculateCurrentOrders(string symbol) {return 1;}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
int OnInit() {
   ObjectCreate(0,"trades",OBJ_LABEL,0,0,0);
   ObjectSetString(0,"trades",OBJPROP_TEXT,"Trades: 0");
   ObjectSetInteger(0,"trades",OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,"trades",OBJPROP_YDISTANCE,50);
   ObjectSetInteger(0,"trades",OBJPROP_COLOR,clrBlack);
   
   ObjectCreate(0,"positions",OBJ_LABEL,0,0,0);
   ObjectSetString(0,"positions",OBJPROP_TEXT,"Positions: 0");
   ObjectSetInteger(0,"positions",OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,"positions",OBJPROP_YDISTANCE,75);
   ObjectSetInteger(0,"positions",OBJPROP_COLOR,clrBlack);
   
   ArrayResize(SLOrders,1);
   ArrayResize(TPOrders,1);
   ArrayResize(Orders,1);
   
   OrderDelay = PeriodSeconds()*3;
   
   log("********** Crackajack Initialized **********");
   return(INIT_SUCCEEDED);
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnDeinit(const int reason) {
   log("Crackajack Deinit. ObjList.size:"+(string)ArraySize(ObjList)+", IsTesting:"+(string)IsTesting());
   log("ObjList:"+strArrayToStr(ObjList));
   
   if(!IsTesting()) {
      ObjectDelete("trades"); 
      ObjectDelete("positions"); 
      ObjectsDeleteAll();
   }
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
double OnTester() {
   log("********** Crackajack Test Complete **********");
   log("********** Test Summary **********");
   log((string)nTrades+" total trades made.");
   log((string)nPositions+" positions open.");
   log((string)nStops+" orders hit StopLoss.");
   log((string)nTakeProfit+" orders hit TakeProfit.");
   log("***********Debug Info ************************");
   //listAllIndicators();
   //listAllIndicators(); 
   log("*********************************************");
   return 0.0;
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnTick() {
   //if(!NewBar())
   //   return;
      
   CheckClosedOrders();
   UpdateOpenPendingOrders();   
   CreateNewOrders();
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
            CreateArrow((string)ticket+"_SL", Symbol(), OBJ_ARROW_STOP,
               iBarShift(Symbol(),0,OrderCloseTime()), clrRed, ObjList);
            ArrayResize(SLOrders,ArraySize(SLOrders)+1);
            SLOrders[ArraySize(SLOrders)-1] = ticket;
            ArraySort(SLOrders, WHOLE_ARRAY, 0, MODE_ASCEND);
            LastOrderDt = Time[0];
            nStops++;
            nPositions--;
            log("Order #"+(string)ticket+" hit SL!");
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
            LastOrderDt = Time[0];
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
   int res;
   bool close_position;
   for(int i=0; i<OrdersTotal(); i++) {
      close_position=false;
      // Load next open/pending order
      bool is_selected = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);      
      if(!is_selected) {
         log("Could not retrieve order. "+err_msg());
         continue;
      }     
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
         
      close_position = GetExitSignal(OrderType());
      
      if(close_position==false)
         continue;
      
      if(close_position == true && OrderType()==OP_SELL) {
         res=OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrBlue);
         CreateArrow((string)OrderTicket()+"_close", Symbol(), OBJ_ARROW_UP,0,clrRed, ObjList);
      }
      else if(close_position == true && OrderType()==OP_BUY) {
         res=OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed);
         CreateArrow((string)OrderTicket()+"_close", Symbol(), OBJ_ARROW_DOWN,0, clrBlue, ObjList);
      }
      
      if(res != 1)
         log("Error closing order "+(string)OrderTicket()+", Reason: "+err_msg());
      else {
         log("Closed "+OrderTypes[OrderType()]+" order #"+(string)OrderTicket());
         LastOrderDt = Time[0];
         nTrades++;
         nPositions--;
      }
   }
}

//+---------------------------------------------------------------------------+
//| Evaluate new positions
//+---------------------------------------------------------------------------+
void CreateNewOrders() {   
   int n_active=0;   
   // Check if we're already holding a position
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
      n_active++;
   }
   if(n_active > 0) {
      //log("Already have "+(string)n_active +" positions open");
      return;
   }
   
   // Check if minimum time has elapsed between orders
   if(LastOrderDt>0 && Time[0]-LastOrderDt<OrderDelay)
      return;

   int oid, type;
   double TP=0.0, SL=0.0, price=0.0;
   int signal = GetEntrySignal();
   
   if(signal==0) {
      //ObjectSetString(0,ntrades_lbl,OBJPROP_TEXT,"Trades:"+(string)nTrades);
      //ObjectSetString(0,npos_lbl,OBJPROP_TEXT,"Positions:"+(string)nPositions);
      return;
   }
   else if(signal==1){  // Buy   
      type=OP_BUY;
      price = Bid;
      TP = Bid + TakeProfit*Point*10;   //0.00001 * 10 = 0.0001
      SL = Bid - StopLoss*Point*10;
      oid = OrderSend(Symbol(),type,GetLots(),Ask,3,SL,TP,"",MAGICMA,0,clrBlue);
      CreateArrow((string)oid+"_open", Symbol(), OBJ_ARROW_UP, 0, clrBlue, ObjList);
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
   
   LastOrderDt = Time[0];
   Orders[ArraySize(Orders)-1] = oid;
   ArraySort(Orders, WHOLE_ARRAY, 0, MODE_ASCEND);
   ArrayResize(Orders,ArraySize(Orders)+1);
   
   nTrades++;
   nPositions++;
   log(OrderTypes[type]+" order #"+(string)oid+", Price:"+(string)price+", TP:"+(string)TP+", SL:"+(string)SL);
}

//+----------------------------------------------------------------------------+
//| 
//+----------------------------------------------------------------------------+
void getBrokerDiscount() {
   double OrderAsk = MarketInfo(Symbol(), MODE_ASK); // Same as "Ask" on the same symbol chart
   double OrderBid = MarketInfo(Symbol(), MODE_BID); // Same as "Bid" on the same symbol chart
   
   double ChartBid = iClose(Symbol(), 0,0); // Provided the data is refreshed on the Symbol(),Period() chart.
   //double ChartAsk = ??; //I don't have method to get the *Chart* Ask. Fyi, it's not SymbolInfoDouble(Symbol(), SYMBOL_ASK )
   
   double myPoint = MarketInfo(Symbol(), MODE_POINT)* MathPow(10,Digits%2); // Scale for true pips (for Fx), never pipettes
   double BidDiscount = (OrderBid-ChartBid)/myPoint;
   //double AskDiscount = (ChartAsk-OrderAsk)/myPoint; // Since ChartAsk isn't possible, I observe that -- for me -- AskDiscount = BidDiscount;
   double AskDiscount = BidDiscount;
   
   double OrderSpread = (OrderAsk - OrderBid)/myPoint;
   double ChartSpread = (OrderSpread+BidDiscount+AskDiscount); // Fyi, my broker seems to have 0.5p each, so 1.0p total discount
   
   log("BidDiscount:"+(string)BidDiscount+", OrderSpread:"+(string)OrderSpread+", ChartSpread:"+(string)ChartSpread);
}
  
//+----------------------------------------------------------------------------+
//| Returns value: 1 for buy signal, -1 for sell signal, 0 otherwise
//+----------------------------------------------------------------------------+
int GetEntrySignal() {      
   
   /***** Determine Trend *****/
   double plus_di100 = iADX(Symbol(),0,100,PRICE_CLOSE,MODE_PLUSDI,1);
   double minus_di100 = iADX(Symbol(),0,100,PRICE_CLOSE,MODE_MINUSDI,1);
   //int trend = plus_di100>minus_di100 ? 1 : minus_di100>plus_di100 ? -1 : 0;
  
   /***** Look for Trigger Signal *****/
   double s1=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,0);
   double s1_prev=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,1);
   double s2=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,1,2);
   double s2_prev=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,1,2+1);
   
   double rsi=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,2,0);
   int trend=rsi<50 ? -1 : rsi>50 ? 1 : 0;
   
   bool ob=s2<StochOB && s2_prev>=StochOB && s2<s1 ? true : false;
   bool os=s2>StochOS && s2_prev<=StochOS && s2>s1 ? true : false;           

   if(trend==1 && os)
      return 1;
   else if(trend==-1 && ob)
      return -1;
   else
      return 0;
   
   //log("Trade signal. Uptrend:"+(string)uptrend+", Downtrend:"+(string)downtrend+
   //   ", EMA1:"+DoubleToStr(ema1,2)+", EMA2:"+DoubleToStr(ema2,2));
}

//+----------------------------------------------------------------------------+
//| Close/hold position.
//| Returns: 1 for close short, -1 for close long, 0 for hold.
//+----------------------------------------------------------------------------+
bool GetExitSignal(int ordertype) {  
   /***** Determine Trend *****/
   return false;
   
   double di= iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double plus_di=iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 1);
   double minus_di=iADX(Symbol(), 0, ADXPeriod,PRICE_CLOSE, MODE_MINUSDI, 1);
   
   if(ordertype==OP_BUY) {   
      if(plus_di < di){
         log("+DI trend died. Close long.");
         return true;
      }
   }
    
   if(ordertype==OP_SELL) {
      if(minus_di < di){
         log("-DI trend died. Close short.");
         return true;
      }
   }
   
   return false;
      
   /*       
   double storsi = iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,0);
   double storsi_prev = iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,1);
   double stosig_prev = iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,1,2+1);
   
   // Close short when StochRSI moves above Overbought line
   if(OrderType()==OP_SELL && storsi_prev<=StochOS && storsi>StochOS)
      return 1;
   // Close long when StochRSI moves below Oversold line
   else if(OrderType()==OP_BUY && storsi_prev>=StochOB && storsi<StochOB)
      return -1;
   else
      return 0;     
   */
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


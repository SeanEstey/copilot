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
void listAllIndicators() {
   long chart_id=ChartFirst();
   while(chart_id != -1) {
      long n_subwindows = ChartGetInteger(chart_id,CHART_WINDOWS_TOTAL,0);
      for(int win_idx=0; win_idx<n_subwindows; win_idx++) {
         int n_indicators = ChartIndicatorsTotal(chart_id, win_idx);
         for(int ind_idx=0; ind_idx<n_indicators; ind_idx++) {
            string ind_name = ChartIndicatorName(chart_id, win_idx, ind_idx);
            log("Chart:"+(string)chart_id+", Window:"+(string)win_idx+", Indicator:"+(string)ind_idx+", Name:"+ind_name);
            
            ResetLastError();
            if(win_idx==3)
               ChartIndicatorDelete(chart_id, 3, ind_name);
            
            // Rename to unique name
            if(StringFind("ADX", ind_name)) {
               bool ss_res=IndicatorSetString(INDICATOR_SHORTNAME,"ADX "+(string)ind_idx);
               IndicatorShortName("ADX "+(string)ind_idx);
               bool si_res=IndicatorSetInteger(INDICATOR_LEVELCOLOR,0,clrRed);  // arg 2: level to change
               log("ss_res:"+(string)ss_res+", si_res:"+(string)si_res+", Details:"+err_msg());
            }
         }
      }
      chart_id=ChartNext(chart_id);
   }
   ChartRedraw(chart_id);
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
   
   Orders[ArraySize(Orders)-1] = oid;
   ArraySort(Orders, WHOLE_ARRAY, 0, MODE_ASCEND);
   ArrayResize(Orders,ArraySize(Orders)+1);
   
   nTrades++;
   nPositions++;
   log(OrderTypes[type]+" order #"+(string)oid+", Price:"+(string)price+", TP:"+(string)TP+", SL:"+(string)SL);
}
  

//+----------------------------------------------------------------------------+
//| Returns value: 1 for buy signal, -1 for sell signal, 0 otherwise
//+----------------------------------------------------------------------------+
int GetEntrySignal() {      
   
   /***** Determine Trend *****/
   double adx_low[2], adx_high[2];
   
   double adx_main=iADX(Symbol(),0,ADXPeriod,PRICE_CLOSE,MODE_MAIN,0);
   adx_high[0] = iADX(Symbol(),0,ADXPeriod,PRICE_CLOSE,MODE_PLUSDI,1);
   adx_high[1] = iADX(Symbol(),0,ADXPeriod,PRICE_CLOSE,MODE_PLUSDI,2);
   adx_low[0]= iADX(Symbol(),0,ADXPeriod,PRICE_CLOSE,MODE_MINUSDI,1);
   adx_low[1] = iADX(Symbol(),0,ADXPeriod,PRICE_CLOSE,MODE_MINUSDI,2);
      
   bool crossover = adx_high[0] > adx_low[0] && adx_high[1] <= adx_low[1] ? true : false;
   bool crossunder = adx_high[0] < adx_low[0] && adx_high[1] >= adx_low[1] ? true : false;
   
   if(crossover==true && adx_high[0] >= ADXRangeLvl) {
      log("ADX("+(string)ADXPeriod+") crossover! -DI[1]:"+DoubleToStr(adx_low[0],2)+", -DI[2]:"+DoubleToStr(adx_low[1],2)+
          ", +DI[1]:"+DoubleToStr(adx_high[0],2)+", +DI[2]:"+DoubleToStr(adx_high[1],2));
      return 1;   
   }
   else if(crossunder==true && adx_low[0] >= ADXRangeLvl) {
      log("ADX("+(string)ADXPeriod+") crossunder! -DI[1]:"+DoubleToStr(adx_low[0],2)+", -DI[2]:"+DoubleToStr(adx_low[1],2)+
          ", +DI[1]:"+DoubleToStr(adx_high[0],2)+", +DI[2]:"+DoubleToStr(adx_high[1],2));
      return -1;
   }
   else
      return 0;
   
   /* Use WindowFind(string name) to get the indexes of the newly drawn indicators to adjust properties */
   
  
   
   /***** Look for Trigger Signal *****/
   /*
   double s1=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,0);
   double s1_prev=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,0,1);
   double s2=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,1,2);
   double s2_prev=iCustom(Symbol(),0,"StochRSI",RSILen,KLen,DLen,Slowing,StochOB,StochOS,1,2+1);
   
   bool ob=s2<StochOB && s2_prev>=StochOB && s2<s1 ? true : false;
   bool os=s2>StochOS && s2_prev<=StochOS && s2>s1 ? true : false;           

   bool golong = sos_trig && fos_trig && uptrend ? true : false;
   bool goshort = sob_trig && fob_trig && downtrend ? true : false;
   
   if(golong || goshort) {
      log("Trade signal. Uptrend:"+(string)uptrend+", Downtrend:"+(string)downtrend+
         ", EMA1:"+DoubleToStr(ema1,2)+", EMA2:"+DoubleToStr(ema2,2));
   }
   return golong ? 1 : goshort ? -1 : 0;
   */
}

//+----------------------------------------------------------------------------+
//| Close/hold position.
//| Returns: 1 for close short, -1 for close long, 0 for hold.
//+----------------------------------------------------------------------------+
bool GetExitSignal(int ordertype) {  
 /***** Determine Trend *****/
  
   if(ordertype==OP_BUY) {
      double adxplus = iADX(Symbol(),0,ADXPeriod,PRICE_CLOSE,MODE_PLUSDI,1);
      if(adxplus <=ADXRangeLvl) {
         log("+DI trend died. Close long.");
         return true;
      }
   }
    
   if(ordertype==OP_SELL) {
      double adxminus = iADX(Symbol(),0,ADXPeriod,PRICE_CLOSE,MODE_MINUSDI,1);
      if(adxminus <=ADXRangeLvl) {
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


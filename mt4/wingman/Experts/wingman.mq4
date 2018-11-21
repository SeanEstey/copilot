//+------------------------------------------------------------------+
//|                                                      wingman.mq4 |
//|                                 Copyright 2018, Wing Enterprises |
//|                                         https://www.wingcorp.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Wing Enterprises"
#property link      "https://www.wingcorp.com"
#property version   "1.00"
#property strict

#define MAGICMA  20131111
#define DEBUG false

//--- Inputs
input double Lots             = 1.0;
input int    TakeProfit       = 15;    
input int    StopLoss         = 5;
input int    RSIPeriod        = 10;
input int    KPeriod          = 10;
input int    DPeriod          = 2;
input int    Slowing          = 2;
input int    StochOverbought  = 90;
input int    StochOversold    = 10;
input int    FisherPeriod     = 9;
input double FisherRange      = 1.25;


double GetLots() {return Lots;}
int CalculateCurrentOrders(string symbol) {return 1;}


//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
int OnInit() {
   string text = "Wingman!";
   ObjectCreate(0,"label",OBJ_LABEL,0,0,0);
   ObjectSetString(0,"label",OBJPROP_TEXT,text);
   ObjectSetInteger(0,"label",OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,"label",OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,"label",OBJPROP_COLOR,clrForestGreen);
   return(INIT_SUCCEEDED);
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   ObjectDelete("label");
}
  
//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnTick() {   
//---
   if(Bars<100 || IsTradeAllowed()==false || !NewBar()) {
      //Print("Could not trade!");
      return;
   }
   if(Volume[0]>1)     // What does this do?!?!?!
      return;
      
   int signal = GenerateSignal();
   
   if(signal==0) {
      //Print("No trade signal.");
      return;
   }
       
   /*** Iterate through open positions, close as necessary ***/
   
   int result=NULL;
   
   for(int i=0; i<OrdersTotal(); i++) {
      // Load current order
      bool is_selected = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);    
      
      if(!is_selected) {
         Print("Could not retrieve order. Error: ", GetLastError());
         continue;
      }     
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA) {
         Print("ERROR: wrong symbol/magic_num. Symbol=", Symbol(), 
            ", MagicNum=", OrderMagicNumber());
         continue;
      }
      
      if(signal == 1 && OrderType() == OP_SELL)
         result = OrderClose(OrderTicket(), OrderLots(), Ask, 3, White);
      // SELL signal. Close long positions. Open short position.
      else if(signal == -1 && OrderType() == OP_BUY)
         result = OrderClose(OrderTicket(), OrderLots(), Bid, 3, White);
      
      if(result != 1) {
         Alert("ERROR closing Order ", OrderTicket());
      }
      else
         Alert("Closed Order ", OrderTicket());
   }
   
   /*** Open Positions. Calculate stops/profit levels (in pips), submit orders ***/
   
   result=NULL;
   double TP=0.0, SL=0.0,  price=0.0;
   
   if(signal == 1) {      // Long
      price = Bid;
      TP = Bid + TakeProfit*Point*10;   //0.00001 * 10 = 0.0001
      SL = Bid - StopLoss*Point*10;
      result = OrderSend(Symbol(),OP_BUY,GetLots(),Ask,3,SL,TP,"",MAGICMA,0,Blue);
   }
   else if(signal == -1) { // Short
      price = Ask;
      TP = Ask - TakeProfit*Point*10;   //0.00001 * 10 = 0.0001
      SL = Ask + StopLoss*Point*10;
      result = OrderSend(Symbol(),OP_SELL,GetLots(),Bid,3,SL,TP,"",MAGICMA,0,Red);
   }
   
   if(result == -1) { 
      double minstoplevel=MarketInfo(Symbol(), MODE_STOPLEVEL);
      Alert("ERROR: SendOrder code ", GetLastError());
      Alert(Symbol(), "minStopLevel=", minstoplevel, " TP=",TP, ", SL=", SL);
   }
   else {
      Print("OrderID:", result, " P:", price, " TP:", TP, " SL:", SL);
   }
   
   return;
}

//+----------------------------------------------------------------------------+
//|**************************** SIGNAL ALGOS *********************************/
//+----------------------------------------------------------------------------+

//+----------------------------------------------------------------------------+
//| Returns value: 1 for buy signal, -1 for sell signal, 0 otherwise
//+----------------------------------------------------------------------------+
int GenerateSignal() {
   double stochrsi = iCustom(NULL,0,"StochRSI", RSIPeriod, KPeriod, DPeriod, Slowing, 0, 0);    // Main buffer: 0
   double signal = iCustom(NULL,0,"StochRSI", RSIPeriod, KPeriod, DPeriod, Slowing, 1, 0);       // Signal buffer: 1
   double fish1 =  iCustom(NULL,0,"FisherTransform", FisherPeriod, 0, 0);    // Main buffer: 0
   double fish2 =  iCustom(NULL,0,"FisherTransform", FisherPeriod, 1, 0);    // Signal buffer: 1
   
   if(stochrsi>100.0 || stochrsi<0 || signal>100.0 || signal<0) {
      if(DEBUG==true)
         Print("Error: StochRSI Out of Bounds. Value="+(string)stochrsi+", Signal="+(string)signal);
      return 0;
   }
   
   if(stochrsi>=StochOverbought && stochrsi < signal) {
      if(fish1 >= FisherRange) { //&& fish2 >= FisherRange) {
         if(DEBUG==true)
            Print("Sell signal. StochRSI=", (int)stochrsi, ", Signal=", (int)signal, ", Fisher1=", fish1, ", Fisher2=", fish2);
         return -1;
      }
   }
   if(stochrsi <= StochOversold && stochrsi > signal) {
      if(fish1 <= FisherRange*-1) { //&& fish2 <= FisherRange*-1) {
         if(DEBUG==true)
            Print("Buy sginal. StochRSI=", (int)stochrsi, ", Signal=", (int)signal, ", Fisher=", fish1);
         return 1;
      }
   }
   
   if(DEBUG==true)
      Print("StochRSI: ", stochrsi, ", Signal: ", signal, ", Fisher: ", fish1);
   return 0;
}


//+-----------------------------------------------------------------------------+
//| 
//+-----------------------------------------------------------------------------+
int HullMA(int length) {
   //hullma(Close, length)=>
   // iMA(2*wma(src, length/2) - WEIGHTED_MA(src, length), round(sqrt(length)))
   // double n2ma = 2 * iMA(NULL,0,n,0
   //n2ma=2*wma(close,round(n/2))
   //nma=wma(close,n)
   //diff=n2ma-nma
   //sqn=round(sqrt(n))
   return 1;
}


//+----------------------------------------------------------------------------+
//|**************************** UTILITY METHODS ******************************/
//+----------------------------------------------------------------------------+

bool NewBar() {
    static datetime lastbar;
    datetime curbar = Time[0];  
    if(lastbar != curbar) {
       lastbar=curbar;
       return true;
    }
    else
      return false;
}


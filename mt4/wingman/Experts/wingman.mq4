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
input int    TakeProfit       = 15;    
input int    StopLoss         = 15;
input int    RSIPeriod        = 10;
input int    KPeriod          = 10;
input int    DPeriod          = 2;
input int    Slowing          = 2;
input int    StochOverbought  = 80;
input int    StochOversold    = 20;
input int    FisherPeriod     = 10;
input double FisherRange      = 0.9;
extern bool  bPlotIndicatorWhenTesting=true;

int nTrades=0;

double GetLots() {return Lots;}
int CalculateCurrentOrders(string symbol) {return 1;}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
int OnInit() {
   int id=0;//ChartID();
   if(IsVisualMode())
      id=0;
      
   string text = "Wingman!";
   ObjectCreate(0,"label",OBJ_LABEL,0,0,0);
   ObjectSetString(0,"label",OBJPROP_TEXT,"nTrades: N/A");
   ObjectSetInteger(0,"label",OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,"label",OBJPROP_YDISTANCE,50);
   ObjectSetInteger(0,"label",OBJPROP_COLOR,clrForestGreen);
   log("********** Wingman Initialized **********");
   return(INIT_SUCCEEDED);
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   //ObjectDelete("label");
   log("SUMMARY. Trades Found: ", (string)nTrades);
   log("********** Wingman Test Complete **********");
   //ObjectSetString(0,"label",OBJPROP_TEXT,"SUMMARY. Trades Found: "+(string)nTrades);
}
  
//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnTick() {   
//---
   if(!NewBar())
      return;
 
   int signal = GenerateSignal();
   if(signal==0) {
      ObjectSetString(0,"label",OBJPROP_TEXT,"Trades: "+(string)nTrades);
      //log("No trade this bar");
      return;
   }
   else {
      nTrades++;
      ObjectSetString(0,"label",OBJPROP_TEXT,"Trades: "+(string)nTrades);
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
         log("ERROR closing Order ", (string)OrderTicket());
      }
      else
         log("Closed Order ", OrderTicket());
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
      log("ERROR: SendOrder code ", GetLastError());
      log(Symbol(), "minStopLevel=", (string)minstoplevel, " TP=",(string)TP, ", SL=", (string)SL);
   }
   else {
      log("OrderID:", result, " P:", (string)price, " TP:", (string)TP, " SL:", (string)SL);
   }
   
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
   string msg="";
   double stochrsi = iCustom(NULL,0,"StochRSI",RSIPeriod,KPeriod,DPeriod,Slowing,0,0);
   double signal = iCustom(NULL,0,"StochRSI",RSIPeriod,KPeriod,DPeriod,Slowing,1,0);
   double fish1 =  iCustom(NULL,0,"FisherTransform", FisherPeriod,FisherRange, 0, 0);
   double fish2 =  iCustom(NULL,0,"FisherTransform", FisherPeriod,FisherRange, 1, 0);
   
   string fish1str = DoubleToString(fish1,2);
   string fish2str = DoubleToString(fish2,2);
   string stochstr = DoubleToString(stochrsi,0);
   string signalstr = DoubleToString(signal,0);
   
   bool stoch_ob = stochrsi>=StochOverbought && signal >=StochOverbought && stochrsi < signal ? true : false;
   bool stoch_os = stochrsi <= StochOversold && signal<=StochOversold && stochrsi > signal ? true : false;
   bool fish_ob = fish1 >= FisherRange || fish2 >= FisherRange ? true : false;
   bool fish_os = fish1 <= FisherRange*-1 || fish2 <= FisherRange*-1 ? true : false;
   
   // Bounds checks & Sanity Tests
   if(stochrsi>100)
      stochrsi=100.0;
   if(signal>100)
      signal=100.0;
   if(stochrsi>100 || stochrsi<0 || signal>100.0 || signal<0 || MathAbs(fish1)>10 || MathAbs(fish2)>10) {
      log("BOUNDS ERROR! StochRSI("+stochrsi+","+signal+"), Fisher(",fish1str,",",fish2str,")");
      return 0;
   }
  
   //if(fish_ob || fish_os)
   //   Print("Fisher signal(",fish1str,",",fish2str,")!");
   //if(stoch_ob || stoch_os)
   //   Print("Stoch signal(",stochstr,",",signalstr,")!");
   
   log("StochRSI("+stochstr+","+signalstr+"), Fisher("+fish1str+","+fish2str+")");
         
   /*** Return Buy/Sell signals ***/
   if(stoch_ob && fish_ob) {
      log("Overbought confluence! StochRSI("+stochstr+","+signalstr+"), Fisher(",fish1str,",",fish2str,")");
      return -1;
   }
    else if(stoch_os && fish_os) {
      log("Oversold confluence! StochRSI("+stochstr+","+signalstr,"), Fisher(",fish1str,",",fish2str,")");
      return 1;
   }
   else
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


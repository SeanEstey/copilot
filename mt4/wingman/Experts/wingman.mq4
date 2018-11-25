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
input int    RSIPeriod        = 14;
input int    KPeriod          = 10;
input int    DPeriod          = 3;
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
   ObjectDelete("label");
   
   log("********** Wingman Test Complete **********");
   log((string)nTrades+" trades made.");
   log("*******************************************");
}
  
//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnTick() {   
//---
 //  if(!NewBar())
 //     return;
 
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
   double stochrsi = iCustom(NULL,0,"StochRSI",RSIPeriod,KPeriod,DPeriod,Slowing,80,20,0,Slowing);
   double signal = iCustom(NULL,0,"StochRSI",RSIPeriod,KPeriod,DPeriod,Slowing,80,20,1,Slowing);
   double fish1 =  iCustom(NULL,0,"FisherTransform", FisherPeriod,FisherRange, 0,0);
   double fish2 =  iCustom(NULL,0,"FisherTransform", FisherPeriod,FisherRange, 1,0);

   bool ob1 = stochrsi>=StochOverbought && signal >=StochOverbought && stochrsi < signal ? true : false;
   bool os1 = stochrsi <= StochOversold && signal<=StochOversold && stochrsi > signal ? true : false;
   bool ob2 = fish1 >= FisherRange || fish2 >= FisherRange ? true : false;
   bool os2 = fish1 <= FisherRange*-1 || fish2 <= FisherRange*-1 ? true : false;
   bool osos = os1 && os2 ? true : false;
   bool obob = ob1 && ob2 ? true : false;
   string s11 = DoubleToString(stochrsi,1);
   string s12 = DoubleToString(signal,1);
   string f11 = DoubleToString(fish1,2);
   string f12 = DoubleToString(fish2,2);
   
   log("Signals: S=["+s11+","+s12+"], F=["+f11+","+f12+"] Confluence OB=["+ob1+","+ob2+"], "+"OS=["+os1+","+os2+
      "], Confluence=["+(osos || obob)+"]"); 
   
   return osos ? 1 : obob ? -1 : 0;
   
   //if(ob1 && os2 || os1 && ob2) {
   //   log("Signal divergence, StochRSI:("+s11+","+s12+"),Fisher(",f11,",",f12,")");
   //   return -1;
   //}
   /* if(stoch_ob && fish_ob) {
      log("Overbought confluence! StochRSI("+stochstr+","+signalstr+"), Fisher(",fish1str,",",fish2str,")");
      return -1;
   }
    else if(stoch_os && fish_os) {
      log("Oversold confluence! StochRSI("+stochstr+","+signalstr,"), Fisher(",fish1str,",",fish2str,")");
      return 1;
   }
   
   else
      return 0; */
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


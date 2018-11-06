//+------------------------------------------------------------------+
//|                                                    robo_test.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict
#define MAGICMA  20131111

//--- Inputs
input double Lots          =0.1;
input double MaximumRisk   =0.02;
input double DecreaseFactor=3;
input int    MovingPeriod  =12;
input int    MovingShift   =6;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   //ChartOpen("GBPUSD")
   //ChartApplyTemplate(0,"default.tpl");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if(Bars<100 || IsTradeAllowed()==false) {
      Print("Could not trade!");
      return;
   }
 
   if(CalculateCurrentOrders(Symbol()) == 0)
      CheckForOpen();
   else              
      CheckForClose();
}

//+------------------------------------------------------------------+
//| 
//+------------------------------------------------------------------+
double LotsOptimized() {
   return Lots;
}

//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
int CheckForOpen() {
   // go trading only for first ticks of new bar
   if(Volume[0]>1)
      return 0;
   
   double ma = iMA(NULL,0,MovingPeriod,MovingShift,MODE_SMA,PRICE_CLOSE,0);    // MA
   
   // Sell?
   if(Open[1]>ma && Close[1]<ma)
      return OrderSend(Symbol(),OP_SELL,LotsOptimized(),Bid,3,0,0,"",MAGICMA,0,Red);
   // Buy?
   else if(Open[1]<ma && Close[1]>ma)
      return OrderSend(Symbol(),OP_BUY,LotsOptimized(),Ask,3,0,0,"",MAGICMA,0,Blue);
   else
      return 0;
}

//+------------------------------------------------------------------+
//| Check for close order conditions                                 |
//+------------------------------------------------------------------+
void CheckForClose() {
   if(Volume[0]>1)
      return;

   double ma;
   ma=iMA(NULL,0,MovingPeriod,MovingShift,MODE_SMA,PRICE_CLOSE,0); // MA

   for(int i=0;i<OrdersTotal();i++) {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
         break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol())
         continue;
      
      // Check order type 
      
      if(OrderType() == OP_BUY) {
         if(Open[1] > ma && Close[1] < ma)
            if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,White))
               Print("OrderClose error ",GetLastError());
         break;
      }
      
      if(OrderType()== OP_SELL) {
         if(Open[1] < ma && Close[1] > ma)
            if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,White))
               Print("OrderClose error ",GetLastError());
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate open positions      
//| Returns: orders volume                                   |
//+------------------------------------------------------------------+
int CalculateCurrentOrders(string symbol) {
   int buys=0,sells=0;

   for(int i=0;i<OrdersTotal();i++) {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA) {
         if(OrderType()==OP_BUY)  buys++;
         if(OrderType()==OP_SELL) sells++;
      }
   }

   if(buys > 0)
      return(buys);
   else
      return(-sells);
}

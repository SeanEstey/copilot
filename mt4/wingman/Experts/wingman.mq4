///////////////////////////////////////////////////////////////////////////////
// Basic scalping script using stochastic rsi and fisher transform signals.
// Recommended settings:
//   15m: stoch @ 10 10 2 2, fisher @ 9
//   240m: stoch @ 8 8 2 2, fisher @ 9
///////////////////////////////////////////////////////////////////////////////

#include <StochRSI.mqh>
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict
#define MAGICMA  20131111

//--- Inputs
//strategy("Wingman",overlay=false, initial_    capital=10000, calc_on_order_fills=true, commission_type=strategy.commission.percent) //commission_value=0.075)
input double Lots           = 0.1;
input double MaximumRisk    = 0.02;
input double DecreaseFactor = 3;
input int    MovingPeriod   = 12;
input int    MovingShift    = 6;
input int    FisherPeriod   = 9; // min:11
input double FisherRange    = 1.5; // min:0.5
input int    RSIPeriod      = 10; // min:1
input int    StochPeriod    = 10; // min:1
input int    StochK         = 2; // min:1
input int    StochD         = 2; // min:1
input int    StochRangeHigh = 80; // min:1
input int    StochRangeLow  = 20; // min:1

double k, d, fish;

double LotsOptimized() {  return Lots; }
int CalculateCurrentOrders(string symbol) { return 1;}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   //ChartOpen("GBPUSD")
   //ChartApplyTemplate(0,"default.tpl");
   Print("Wingman Robot Init");
   Print("Bars=" + (string)Bars);
   OnStart();

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
   
   // Manage
   int buys=0,sells=0;

   for(int i=0;i<OrdersTotal();i++) {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA) {
            if(OrderType()==OP_BUY)  buys++;
            if(OrderType()==OP_SELL) sells++;
      }
   }
   
   //FisherTransform(1);
   

   if(buys > 0)
      return;//(buys);
   else
      return;//(-sells);
   if(CalculateCurrentOrders(Symbol()) == 0)
      CheckForOpen();
   else              
      CheckForClose();
}

//+-----------------------------------------------------------------------+
// Manage Positions on confluences
//    Entry: 1) stoch cross, 2) stoch extreme, 3) fisher extreme
//    Exit: opposite stoch extreme
//+-----------------------------------------------------------------------+
int CheckForOpen() {
   if(Volume[0]>1)
      return 0;
   
   bool GoLong = true;     // PLACEHOLDER
   bool GoShort = true;    // PLACEHOLDER
   //bool GoLong = sto_oversd and fish < FisherRange*-1 and fish[1] < FisherRange*-1;
   //bool GoShort = sto_overbt and fish > FisherRange and fish[1] > FisherRange
   
   // strategy.entry("Long", strategy.long, when=window() and go_long)
   // strategy.entry("Short", strategy.short, when=window() and go_short)

   if(GoShort)
      return OrderSend(Symbol(),OP_SELL,LotsOptimized(),Bid,3,0,0,"",MAGICMA,0,Red);
   else if(GoLong)
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
      
   // strategy.close("Long", when=strategy.position_size > 0 and (k[1] >= StochRangeHigh) or stop_long)
   // strategy.close("Short", when=strategy.position_size > 0 and (k[1] <= StochRangeLow) or stop_short)

   for(int i=0;i<OrdersTotal();i++) {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
         break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol())
         continue;
      
      if(OrderType() == OP_BUY) {
         //if(Open[1] > ma && Close[1] < ma)
            if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,White))
               Print("OrderClose error ",GetLastError());
         break;
      }
      
      if(OrderType()== OP_SELL) {
         //if(Open[1] < ma && Close[1] > ma)
            if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,White))
               Print("OrderClose error ",GetLastError());
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| RSI = speed of price movements. suited for trending markets
//| Stochastics = momentum oscillator suited for  ranges
//| %K: current closing prices in relation to the defined high and low period.
//| %D: SMA of the %K
//+------------------------------------------------------------------+
int StochRSI() {
   
   /* Call iCustom with StochRSI.mq4 */
   
   //bool oversold = k <= StochRangeLow and crossover(k[1], d[1]) and k[2] <= d[2];
   //bool overbought = k >= StochRangeHigh and crossunder(k[1], d[1]) and k[2] >= d[2];
   return 1;
}

//+------------------------------------------------------------------+
//| Fisher Transform. Adapted from HPotter (v1.0 01/07/2014)
//| 1 == oversold, -1 == overbought
//+------------------------------------------------------------------+
double FisherTransform(int period) {
   /***** PINE SCRIPT CODE *****
      f_val1 = na, f_val2 = na, fish = na, f_stepln = na
      f_minl = lowest(hl2,f_len)
      f_maxh = highest(hl2, f_len)
      f_val1 := (0.33 * 2 * ((hl2 - f_minl) / (f_maxh - f_minl) - 0.5)) + 0.67 * nz(f_val1[1])
      f_val2 := iff(f_val1 > .99,  .999, iff(f_val1 < -.99, -.999, f_val1))
      fish := 0.5 * log((1 + f_val2) / (1 - f_val2)) + 0.5 * nz(fish[1])
      
      // 1 == oversold, -1 == overbought
      if(fish >= f_xtrm)
          f_stepln := iff(fish < fish[1], -1, nz(f_stepln[1], 0))
      if(fish <= f_xtrm * -1)
          f_stepln := iff(fish > fish[1], 1, nz(f_stepln[1],0))
      if(fish < f_xtrm*-1 and fish > f_xtrm)
          f_stepln := 0
   /*****************************/
   
   Print("ArraySize(Close)=" + (string)ArraySize(Close));
   
   double hl2 = (High[0] - Low[0])/2;
   for(int i=ArraySize(Close)-1; i>=0; i--) {
      hl2 = (High[i] - Low[i]) / 2;
   }
   
   Print(hl2);
   return hl2;
   
   /*
   
   double f_minl = iLowest(NULL, 0, MODE_LOW, hl2, FisherPeriod);
   double f_maxh = iHighest(hl2, FisherPeriod);
   
   double f_val1 = (0.33 * 2 * ((hl2 - f_minl) / (f_maxh - f_minl) - 0.5)) + 0.67 * nz(f_val1[1]);
   double f_val2 = iff(f_val1 > .99,  .999, iff(f_val1 < -.99, -.999, f_val1));
   
   fish = 0.5 * log((1 + f_val2) / (1 - f_val2)) + 0.5 * nz(fish[1]);
   
   if(fish >= FisherRange)
       f_stepln = iff(fish < fish[1], -1, nz(f_stepln[1], 0));
   if(fish <= FisherRange * -1)
       f_stepln = iff(fish > fish[1], 1, nz(f_stepln[1],0));
   if(fish < FisherRange*-1 and fish > FisherRange)
       f_stepln = 0;
       
    */
}

//+------------------------------------------------------------------+
//| 
//+------------------------------------------------------------------+
int HullMA(int n) {

   // double n2ma = 2 * iMA(NULL,0,n,0
   //n2ma=2*wma(close,round(n/2))
   //nma=wma(close,n)
   //diff=n2ma-nma
   //sqn=round(sqrt(n))
   return 1;
}

//+------------------------------------------------------------------+
//| 
//+------------------------------------------------------------------+
void Plots() {
   /*** STOCH RSI PLOTS 
   plot(k, color=blue)
   plot(d, color=orange)
   // Green column higher if stoch is deeper
   plot(k[1] >= d[1] and k[2] <= d[2] and k <= 60 and k >= 10 ? data : na , style=columns,color=green,title="Cross Up Confirmed")           
   // Red column higher if stoch is higher
   plot(k[1] <= d[1] and k[2] >= d[2] and k >= 40 and k <= 95 ? data2 : na , style=columns,color=red, title="Cross Down Confirmed")           
   ***/
   
}


void OnStart() 
  { 
   Print("Symbol name of the current chart=",_Symbol); 
   Print("Timeframe of the current chart=",_Period); 
   Print("The latest known seller's price (ask price) for the current symbol=",Ask); 
   Print("The latest known buyer's price (bid price) of the current symbol=",Bid);    
   Print("Number of decimal places=",Digits); 
   Print("Number of decimal places=",_Digits); 
   Print("Size of the current symbol point in the quote currency=",_Point); 
   Print("Size of the current symbol point in the quote currency=",Point);    
   Print("Number of bars in the current chart=",Bars); 
   Print("Open price of the current bar of the current chart=",Open[0]); 
   Print("Close price of the current bar of the current chart=",Close[0]); 
   Print("High price of the current bar of the current chart=",High[0]); 
   Print("Low price of the current bar of the current chart=",Low[0]); 
   Print("Time of the current bar of the current chart=",Time[0]); 
   Print("Tick volume of the current bar of the current chart=",Volume[0]); 
   Print("Last error code=",_LastError); 
   Print("Random seed=",_RandomSeed); 
   Print("Stop flag=",_StopFlag); 
   Print("Uninitialization reason code=",_UninitReason);    
  }
  

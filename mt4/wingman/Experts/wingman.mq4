///////////////////////////////////////////////////////////////////////////////
// Basic scalping script using stochastic rsi and fisher transform signals.
// Recommended settings:
//   15m: stoch @ 10 10 2 2, fisher @ 9
//   240m: stoch @ 8 8 2 2, fisher @ 9
///////////////////////////////////////////////////////////////////////////////

#property copyright ""
#property link      ""
#property version   "1.00"
#property strict
#define MAGICMA  20131111

//--- Inputs
input double Lots             = 0.1;
input double MaximumRisk      = 0.02;
input double DecreaseFactor   = 3;
input int    MovingPeriod     = 12;
input int    MovingShift      = 6;
input int    FisherPeriod     = 9; // min:11
input double FisherRange      = 1.5; // min:0.5
input int    RSIPeriod        = 10; // min:1
input int    StochPeriod      = 10; // min:1
input int    StochK           = 2; // min:1
input int    StochD           = 2; // min:1
input int    StochOverbought  = 90; // min:1
input int    StochOversold    = 10; // min:1


//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
int OnInit() {
   OnStart();
   return(INIT_SUCCEEDED);
}

//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnDeinit(const int reason) {}
  
//+---------------------------------------------------------------------------+
//| MT4 Event Handler
//+---------------------------------------------------------------------------+
void OnTick() {
   if(Bars<100 || IsTradeAllowed()==false || !NewBar()) {
      //Print("Could not trade!");
      return;
   }
   // What does this do?!?!?!
   if(Volume[0]>1)
      return;
      
   int signal = GenerateSignal();
   
   if(signal==0) {
      //Print("No trade signal.");
      return;
   }
      
   //Print("OrdersTotal=",OrdersTotal());
   
   for(int i=0; i<OrdersTotal(); i++) {
      bool is_selected = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);    // Load current order
      
      if(!is_selected) {
         Print("Could not retrieve order. Error: ", GetLastError());
         continue;
      }     
      
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA) {
         Print("ERROR: wrong symbol/magic_num. Symbol=", Symbol(), ", MagicNum=", OrderMagicNumber());
         continue;
      }
      
      // BUY signal. Close short positions. Open long position.
      if(signal == 1 && OrderType() == OP_SELL) {
         Print("Closing short positions");   
         int res = OrderClose(OrderTicket(), OrderLots(), Ask, 3, White);
         Print("Result:", res);      
      }
      // SELL signal. Close long positions. Open short position.
      else if(signal == -1 && OrderType() == OP_BUY) {
         Print("Closing long positions");
         int res = OrderClose(OrderTicket(), OrderLots(), Bid, 3, White);
         Print("Result:", res);
      } 
   }
   
   // Open long position.
   if(signal == 1) {
      int res = OrderSend(Symbol(), OP_BUY, LotsOptimized(), Ask, 3, 0, 0, "", MAGICMA, 0, Red);
      Print("LONG order value: ", res);
   }
   // Open short position.
   else if(signal == -1) {
      int res = OrderSend(Symbol(), OP_SELL, LotsOptimized(), Bid, 3, 0, 0, "", MAGICMA, 0, Blue);
      Print("SHORT order value: ", res);
   }
   
   return;
}

//+----------------------------------------------------------------------------
//***************************** SIGNAL ALGOS *********************************/
//+----------------------------------------------------------------------------

//+-----------------------------------------------------------------------------
// Returns value: 1 for buy signal, -1 for sell signal, 0 otherwise
//+-----------------------------------------------------------------------------
int GenerateSignal() {
   double stochrsi = iCustom(NULL,0,"StochRSI",0,0);    // Main buffer: 0
   double signal = iCustom(NULL,0,"StochRSI",1,0);       // Signal buffer: 1
   
   //Print("StochRSI: " + (string)stochrsi + ", Signal: " + (string)signal);
   
   if(stochrsi>100.0 || stochrsi<0 || signal>100.0 || signal<0) {
      Print("Error: StochRSI Out of Bounds. Value="+(string)stochrsi+", Signal="+(string)signal);
      return 0;
   }
   
   if(stochrsi>=StochOverbought && stochrsi < signal) {
      Print("Overbought. StochRSI=", (int)stochrsi, ", Signal=", (int)signal, ". Sell!");
      return -1;
   }
   
   if(stochrsi <= StochOversold && stochrsi > signal) {
      Print("Oversold. StochRSI=", (int)stochrsi, ", Signal=", (int)signal, ". Buy!");
      return 1;
   }
   
   //Print("No Buy/Sell signal");
   return 0;
}

//+-----------------------------------------------------------------------------
//| Fisher Transform. Adapted from HPotter (v1.0 01/07/2014)
//| 1 == oversold, -1 == overbought
//+-----------------------------------------------------------------------------
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

//+-----------------------------------------------------------------------------
//| 
//+-----------------------------------------------------------------------------
int HullMA(int n) {
   // double n2ma = 2 * iMA(NULL,0,n,0
   //n2ma=2*wma(close,round(n/2))
   //nma=wma(close,n)
   //diff=n2ma-nma
   //sqn=round(sqrt(n))
   return 1;
}



//+----------------------------------------------------------------------------
//***************************** UTILITY METHODS ******************************/
//+----------------------------------------------------------------------------

double LotsOptimized() {  return Lots; }

int CalculateCurrentOrders(string symbol) { return 1;}

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

void OnStart() {
   Print("Wingman Robot Init");
   Print("Bars=" + (string)Bars);
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

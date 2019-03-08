//+---------------------------------------------------------------------------+
//|                                                      Include/Algos/SR.mqh |      
//+---------------------------------------------------------------------------+
#property strict

#include "../Include//Logging.mqh"
#include "../Include//Draw.mqh"
#include "../Include//Chart.mqh"

enum Signals {NONE, OPEN_LONG, CLOSE_LONG, OPEN_SHORT, CLOSE_SHORT};


//+------------------------------------------------------------------+
//| Returns: Signal enum
//+------------------------------------------------------------------+
int ScanLevels(int nbars){
   double low=iLow(NULL,0,iLowest(NULL,0,MODE_LOW,nbars,0));
   double high=iHigh(NULL,0,iHighest(NULL,0,MODE_HIGH,nbars,0));
   
   int pips=ToPips(high-low);
   debuglog("ScanLevels() bars: "+(string)nbars+", pips: "+(string)pips);
   
   return 1;
}


//+------------------------------------------------------------------+
//| Returns: Signal enum
//+------------------------------------------------------------------+
int GetSignal(){
   return 1;
}
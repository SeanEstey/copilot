//+---------------------------------------------------------------------------+
//|                                                               FX/Divs.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property version   "1.00"
#property strict

//--- Custom includes
#include "Logging.mqh"
#include "Utility.mqh"

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
class Divs {      
   public:
   
   Divs(){}
   ~Divs(){}
};



//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int FindDivs(string symbol1, string symbol2){
   /* dollar index with other dollar pairs
    dollar index makes HH, gbpusd makes LL, if gbpusd makes lower high then they accumulating gbpusd

}
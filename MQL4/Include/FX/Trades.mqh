//+---------------------------------------------------------------------------+
//|                                                             FX/Trades.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict

//--- Custom includes
#include <FX/Logging.mqh>
#include <FX/Utility.mqh>

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
class Trades {      
   public:
   
   Trades(){}
   ~Trades(){}
};


//+---------------------------------------------------------------------------+
//| Setup #1 (Very High Prob): new STL confirms ealier ITL and LTL. Open long 
//| Setup #2 (Very High Prob): new STH confirms ealier ITH and LTH. Open short 
//| Setup #3 (High Prob): new STL confirms earlier ITL. Open long 
//| Setup #4 (High Prob): new STH confirms ealier ITH. Open short 
//+---------------------------------------------------------------------------+
int FindSetups(){
  return 1;
}
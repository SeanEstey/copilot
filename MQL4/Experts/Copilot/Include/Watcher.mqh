//+---------------------------------------------------------------------------+
//|                                                       Include/Watcher.mq4 |      
//+---------------------------------------------------------------------------+
#property strict
#include "Logging.mqh"
#include "OrderManager.mqh"

enum LevelReaction {SFP,BOUNCE,BREAK};
enum ReactionDirection {BULLISH,BEARISH};
enum SetupState {PENDING,VALIDATED,INVALIDATED};
enum ConditionState {MET,UNMET,FAILED};

//----------------------------------------------------------------------------+
//|*************************** Class Interfaces ******************************|
//----------------------------------------------------------------------------+

class Condition {
   public:
      uint id;
      string symbol;
      int tf;
      double level;
      LevelReaction reaction;
      ReactionDirection dir;
      ConditionState state;
   public:
      Condition(string _symbol, int _tf, double _level, LevelReaction _reaction, ReactionDirection _dir);
      ~Condition();
      ConditionState Test();
      string ToString();
};


//+---------------------------------------------------------------------------+
class TradeSetup {
   public:
      uint id;
      string symbol;
      int tf;
      SetupState state;
      Order* order;
      Condition* conditions[];
   public:
      TradeSetup(string _symbol, int _tf, Condition* _condition, Order* _order);
      ~TradeSetup();
      int Add(Condition* c);
      int Rmv(Condition* c);
      SetupState Eval();
};

//+---------------------------------------------------------------------------+
class Watcher {
   private:
      TradeSetup* setups[];
   public:
      Watcher();
      ~Watcher();
      int Add(TradeSetup* setup);
      int Rmv(TradeSetup* setup);
      int PauseAll();
      int ClearAll();
      bool Eval(TradeSetup* setup);
      int TickUpdate();
};

//----------------------------------------------------------------------------+
//|****************************** Condition Methods **************************|
//----------------------------------------------------------------------------+

//+---------------------------------------------------------------------------+
Condition::Condition(string _symbol, int _tf, double _level, LevelReaction _reaction, ReactionDirection _dir){
   this.id=GetTickCount(); // FIXME: ID may not be unique if constructor called twice in same millisecond span
   this.symbol=_symbol;
   this.tf=_tf;
   this.level=_level;
   this.reaction=_reaction;
   this.dir=_dir;
   this.state=UNMET;
}

//+---------------------------------------------------------------------------+
Condition::~Condition(){
   // WRITEME
}

//+---------------------------------------------------------------------------+
ConditionState Condition::Test(){
   if(this.state!=UNMET)
      return this.state;
   
   // For readability
   double open=iOpen(this.symbol,this.tf,1);
   double close=iClose(this.symbol,this.tf,1);
   double low=iLow(this.symbol,this.tf,1);
   double high=iHigh(this.symbol,this.tf,1);
    
   // FIXME: detect case where high/low/close==this.level
   // SFP states: MET/UNMET/FAILED
   if(reaction==SFP){
      if(dir==BULLISH && low<level && close>level)
         state=MET;
      else if(dir==BULLISH && low<level && close<level)
         state=FAILED;
      else if(dir==BEARISH && high>level && close<level)
         state=MET;
      else if(dir==BEARISH && high>level && close>level)
         state=FAILED;
   }
   // Level break states: MET/UNMET
   else if(reaction==BREAK){
      if(dir==BULLISH && open<level && close>level)
         state=MET;
      else if(dir==BEARISH && open>level && close<level)
         state=MET;
   }
   // Bounce states: PENDING, VALIDATED or INVALIDATED
   else if(reaction==BOUNCE){
      // WRITEME
   }
   
   if(state!=UNMET){
      log((dir==BULLISH? "Bullish ": "Bearish ")+
         (reaction==SFP? "SFP ": reaction==BREAK? "Break ": reaction==BOUNCE? "Bounce ": "")+
         "pattern "+(state==MET? "MET": "FAILED")
      );
   }
   return this.state;
}

//+---------------------------------------------------------------------------+
string Condition::ToString(){
   string str=this.reaction==SFP? "SFP": 
      this.reaction==BOUNCE? "BOUNCE": 
      this.reaction==BREAK? "BREAK": "NONE";
   return "Setup Condition. Symbol: "+this.symbol+", Tf: "+
      (string)this.tf+", Lvl: "+DoubleToStr(this.level)+", Reaction: "+str;
}


//----------------------------------------------------------------------------+
//|************************ TradeSetup Methods *******************************|
//----------------------------------------------------------------------------+


//+---------------------------------------------------------------------------+
TradeSetup::TradeSetup(string _symbol, int _tf, Condition* _condition, Order* _order){
   this.id=GetTickCount(); // FIXME: ID may not be unique if constructor called twice in same millisecond span
   this.symbol=_symbol;
   this.tf=_tf;
   this.order=_order;
   this.Add(_condition);
   this.state=PENDING;
}

//+---------------------------------------------------------------------------+
TradeSetup::~TradeSetup(){
   // WRITEME
}

//+---------------------------------------------------------------------------+
int TradeSetup::Add(Condition* c){
   ArrayResize(this.conditions, ArraySize(this.conditions)+1);
   this.conditions[ArraySize(this.conditions)-1]=c;
   return 1;
}

//+---------------------------------------------------------------------------+
int TradeSetup::Rmv(Condition* c){
   for(int i=0; i<ArraySize(this.conditions); i++){
      if(this.conditions[i].id!=c.id)
         continue;
      
      int s1=ArraySize(this.conditions);
      /*** TESTME: What lib is this from? Not found in docs ***/
      ArrayRemove(this.conditions,i,1);
      log("Condition ID "+(string)c.id+" removed from setup ("+
         (string)s1+"-->"+(string)ArraySize(this.conditions)
      );
   }
   return 1;
}

//+---------------------------------------------------------------------------+
//| Evaluate conditions and execute trade if met, rmv setup if invalidated.
//+---------------------------------------------------------------------------+
SetupState TradeSetup::Eval(){
   int n_met=0, n_failed=0, n_unmet=0;
   
   for(int i=0; i<ArraySize(this.conditions); i++){
      Condition* c=this.conditions[i];
      
      if(c.state==FAILED){
         n_failed++;
         continue;
      }
         
      c.Test();
      
      if(c.state==UNMET)
         n_unmet++;
      else if(c.state==MET)
         n_met++;
      else if(c.state==FAILED)
         n_failed++;
   }
   
   string msg="Unmet: "+(string)n_unmet+", Met: "+(string)n_met+", Failed: "+(string)n_failed;
   
   if(n_met==ArraySize(this.conditions)){
      this.state=VALIDATED;
      log("TradeSetup ID "+(string)id+": Validated ("+msg+")");
   }
   else if(n_failed>0){
      this.state=INVALIDATED;
      log("TradeSetup ID "+(string)id+": Invalidated ("+msg+")");
   }
   return this.state;
}


//----------------------------------------------------------------------------+
//|*************************** Watcher Methods *******************************|
//----------------------------------------------------------------------------+


//+---------------------------------------------------------------------------+
Watcher::Watcher(){}

//+---------------------------------------------------------------------------+
Watcher::~Watcher(){}

//+---------------------------------------------------------------------------+
int Watcher::Add(TradeSetup* setup){
   ArrayResize(this.setups, ArraySize(this.setups)+1);
   this.setups[ArraySize(this.setups)-1]=setup;
   return 1;
}

//+---------------------------------------------------------------------------+
int Watcher::Rmv(TradeSetup* setup){
   /*** FIXME: test if setup has EXECUTING state, send warning to user ***/
   //ArrayRemove(this.setups,i,1);
   return -1;
}

//+---------------------------------------------------------------------------+
int Watcher::PauseAll(){
   return -1;
}

//+---------------------------------------------------------------------------+
int Watcher::ClearAll(){
   return -1;
}

//+---------------------------------------------------------------------------+
int Watcher::TickUpdate(){
   for(int i=0; i<ArraySize(this.setups); i++){
      TradeSetup* setup=this.setups[i];
      SetupState s=setup.Eval();
      
      if(s==VALIDATED){
         // WRITEME: Execute trade
         
      }
      else if(s==INVALIDATED){
         // WRITEME: Remove setup from watchlist
      }      
   }
   return -1;
}
//+---------------------------------------------------------------------------+
//|                                                  Include/Watcher.mq4 |      
//+---------------------------------------------------------------------------+
#property strict
#include "Logging.mqh"
#include "OrderManager.mqh"

enum LevelReaction {SFP,BOUNCE,BREAK};
enum ReactionDirection {BULLISH, BEARISH};
enum SetupState {WATCHING,EXECUTING,COMPLETED};
enum ConditionState {PENDING,VALIDATED,INVALIDATED};

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
      ConditionState Eval();
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
      int AddCondition(Condition* c);
      int RmvCondition(Condition* c);
      bool Eval();
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
//|************************ Condition Implementation**************************|
//----------------------------------------------------------------------------+

//+---------------------------------------------------------------------------+
Condition::Condition(string _symbol, int _tf, double _level, LevelReaction _reaction, ReactionDirection _dir){
   
   /*** FIXME: needs to be unique, might create conflicts if 
    multiple constructors called within same millisecond span ***/
   this.id=GetTickCount(); 
   
   this.symbol=_symbol;
   this.tf=_tf;
   this.level=_level;
   this.reaction=_reaction;
   this.dir=_dir;
   this.state=PENDING;
}

//+---------------------------------------------------------------------------+
Condition::~Condition(){
   // WRITEME
}

//+---------------------------------------------------------------------------+
ConditionState Condition::Eval(){
   if(!this.state==PENDING)
      return this.state;
   
   // For readability
   double open=iOpen(this.symbol,this.tf,1);
   double close=iClose(this.symbol,this.tf,1);
   double low=iLow(this.symbol,this.tf,1);
   double high=iHigh(this.symbol,this.tf,1);
    
   // SFP states: PENDING, VALIDATED, or INVALIDATED
   // FIXME: detect case where high/low/close==this.level
   if(reaction==SFP){
      if(dir==BULLISH && low<level && close>level)
         state=VALIDATED;
      else if(dir==BULLISH && low<level && close<level)
         state=INVALIDATED;
      else if(dir==BEARISH && high>level && close<level)
         state=VALIDATED;
      else if(dir==BEARISH && high>level && close>level)
         state=INVALIDATED;
   }
   // Level break states: PENDING or VALIDATED (cannot be invalidated)
   else if(reaction==BREAK){
      if(dir==BULLISH && open<level && close>level)
         state=VALIDATED;
      else if(dir==BEARISH && open>level && close<level)
         state=VALIDATED;
   }
   // Bounce states: PENDING, VALIDATED or INVALIDATED
   else if(reaction==BOUNCE){
      // WRITEME
   }
   
   if(state!=PENDING){
      log((dir==BULLISH? "Bullish ": "Bearish ")+
         (reaction==SFP? "SFP ": reaction==BREAK? "Break ": reaction==BOUNCE? "Bounce ": "")+
         "pattern "+(state==VALIDATED? "VALIDATED": "INVALIDATED")
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
//|************************ TradeSetup Implementation*************************|
//----------------------------------------------------------------------------+

//+---------------------------------------------------------------------------+
TradeSetup::TradeSetup(string _symbol, int _tf, Condition* _condition, Order* _order){
   this.symbol=_symbol;
   this.tf=_tf;
   this.order=_order;
   this.AddCondition(_condition);
   this.state=WATCHING;
}

//+---------------------------------------------------------------------------+
TradeSetup::~TradeSetup(){
}

//+---------------------------------------------------------------------------+
int TradeSetup::AddCondition(Condition* c){
   ArrayResize(this.conditions, ArraySize(this.conditions)+1);
   this.conditions[ArraySize(this.conditions)-1]=c;
   return 1;
}

//+---------------------------------------------------------------------------+
int TradeSetup::RmvCondition(Condition* c){
   for(int i=0; i<ArraySize(this.conditions); i++){
      if(this.conditions[i].id!=c.id)
         continue;
      
      int s1=ArraySize(this.conditions);
      /*** TESTME: What lib is this from? Not found in docs ***/
      ArrayRemove(this.conditions,i,1);
      log("Condition ID "+(string)c.id+" removed from setup ("+(string)s1+"-->"+(string)ArraySize(this.conditions));
   }
   return 1;
}

//+---------------------------------------------------------------------------+
Watcher::Watcher(){
}

//+---------------------------------------------------------------------------+
Watcher::~Watcher(){
}

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
bool Watcher::Eval(TradeSetup* strat){
   return false;
}

//+---------------------------------------------------------------------------+
int Watcher::TickUpdate(){

   for(int i=0; i<ArraySize(this.setups); i++){
      if(this.setups[i].state==COMPLETED)
         continue;
      if(this.setups[i].state==WATCHING){
         // Test if setup conditions are ready
      }
      else if(this.setups[i].state==EXECUTING){
         // Test if position has closed since last tick update
      }
   
   }
   
   return -1;
}
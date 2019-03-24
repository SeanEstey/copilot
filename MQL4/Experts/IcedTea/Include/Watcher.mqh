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
      string symbol;
      int tf;
      double level;
      LevelReaction reaction;
      ReactionDirection dir;
      ConditionState status;
   public:
      Condition(string _symbol, int _tf, double _level, LevelReaction _reaction, ReactionDirection _dir);
      ~Condition();
      ConditionState Eval();
      string ToString();
};


//+---------------------------------------------------------------------------+
class TradeSetup {
   public:
      string symbol;
      int tf;
      SetupState status;
      Order* order;
      Condition* conditions[];
   public:
      TradeSetup(string _symbol, int _tf, Condition* _condition, Order* _order);
      ~TradeSetup();
      //SetupState GetStatus() {return this.status;}
      int AddCondition(Condition* _condition);
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
//|**************************** Class Definitions ****************************|
//----------------------------------------------------------------------------+

//+---------------------------------------------------------------------------+
Condition::Condition(string _symbol, int _tf, double _level, LevelReaction _reaction, ReactionDirection _dir){
   this.symbol=_symbol;
   this.tf=_tf;
   this.level=_level;
   this.reaction=_reaction;
   this.dir=_dir;
   this.status=PENDING;
}

//+---------------------------------------------------------------------------+
Condition::~Condition(){
   // WRITEME
}

//+---------------------------------------------------------------------------+
ConditionState Condition::Eval(){
   if(!this.status==PENDING)
      return this.status;
    
   /*** FIXME: detect case where high/low/close == this.level ***/
   // SFP states: PENDING, VALIDATED, or INVALIDATED
   if(this.reaction==SFP){
      if(this.dir==BULLISH && iLow(this.symbol,this.tf,1)<this.level){
         if(iClose(this.symbol,this.tf,1)>this.level){
            this.status=VALIDATED;
            log("Bullish SFP condition VALIDATED.");
         }
         else {
            this.status=INVALIDATED;
            log("Bullish SFP condition INVALIDATED.");
         }
      }
      else if(this.dir==BEARISH && iHigh(this.symbol,this.tf,1)>this.level){
         if(iClose(this.symbol,this.tf,1)<this.level){
            this.status=VALIDATED;
            log("Bearish SFP condition VALIDATED.");
         }
         else {
            this.status=VALIDATED;
            log("Bearish SFP condition INVALIDATED.");
         }
      }
   }
   // Level break states: PENDING or VALIDATED (cannot be invalidated)
   else if(this.reaction==BREAK){
      if(this.dir==BULLISH && iOpen(this.symbol,this.tf,1)<this.level && iClose(this.symbol,this.tf,1)>this.level){
         log("Bullish level BREAK condition validated.");
         this.status=VALIDATED;
      }
      else if(this.dir==BEARISH && iOpen(this.symbol,this.tf,1)>this.level && iClose(this.symbol,this.tf,1)<this.level){
         log("Bullish level BREAK condition validated.");
         this.status=VALIDATED;
      }
   }
   // Bounce states: PENDING, VALIDATED or INVALIDATED
   else if(this.reaction==BOUNCE){
      // WRITEME
   }
   
   return this.status;
}

//+---------------------------------------------------------------------------+
string Condition::ToString(){
   string strreact=this.reaction==SFP? "SFP": this.reaction==BOUNCE? "BOUNCE": this.reaction==BREAK? "BREAK": "NONE";
   return "Setup Condition. Symbol: "+this.symbol+", Tf: "+(string)this.tf+", Lvl: "+DoubleToStr(this.level)+", Reaction: "+strreact;
}


//+---------------------------------------------------------------------------+
TradeSetup::TradeSetup(string _symbol, int _tf, Condition* _condition, Order* _order){
   this.symbol=_symbol;
   this.tf=_tf;
   this.order=_order;
   this.AddCondition(_condition);
   this.status=WATCHING;
}

//+---------------------------------------------------------------------------+
TradeSetup::~TradeSetup(){
}

//+---------------------------------------------------------------------------+
int TradeSetup::AddCondition(Condition* _condition){
   ArrayResize(this.conditions, ArraySize(this.conditions)+1);
   this.conditions[ArraySize(this.conditions)-1]=_condition;
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
      if(this.setups[i].status==COMPLETED)
         continue;
      if(this.setups[i].status==WATCHING){
         // Test if setup conditions are ready
      }
      else if(this.setups[i].status==EXECUTING){
         // Test if position has closed since last tick update
      }
   
   }
   
   return -1;
}
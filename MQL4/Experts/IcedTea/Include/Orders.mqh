//+---------------------------------------------------------------------------+
//|                                                                Orders.mq4 |      
//+---------------------------------------------------------------------------+
#property strict

#include "Logging.mqh"
#include "Draw.mqh"

#define MAGICMA         9516235  
#define LOTS            1.0
#define TAKE_PROFIT     75
#define STOP_LOSS       25

//----------------------------------------------------------------------------+
//|****************************** Order Class **************************
//----------------------------------------------------------------------------+
class Order {
   public:   
      string Symbol;
      int Ticket;
      int Type;         // enum: OP_BUY, OP_SELL, OP_BUYLIMIT, OP_SELLLIMIT
      double Lots;
      int Sl;           // Pips
      int Tp;           // Pips
      double Profit;
   public:
      Order(int _ticket, string _symbol, int _otype, double _lots, int _sl, int tp, double _profit);
      ~Order();
};

//----------------------------------------------------------------------------+
//|****************************** TradeManager Class **************************
//----------------------------------------------------------------------------+
class TradeManager {
   public:
      TradeManager();
      ~TradeManager();
      int GetNumActiveOrders();
      Order* GetActiveOrder();
      double GetTotalProfit(bool unrealized=true);
      string GetHistoryStats();
      string GetAcctStats();
      string ToString();
      int OpenPosition(string symbol, int otype, double price=0.0, double lots=1.0, int tp=75, int sl=25);
      void ClosePosition(int ticket);
      void CloseAllPositions();
      bool HasExistingPosition(string symbol, int otype);
};


//----------------------------------------------------------------------------+
//|**************************** Method Definitions ****************************
//----------------------------------------------------------------------------+

//+---------------------------------------------------------------------------+
Order::Order(int _ticket, string _symbol, int _otype, double _lots, int _sl, int _tp, double _profit){
   this.Symbol=_symbol;
   this.Ticket=_ticket;
   this.Type=_otype;
   this.Lots=_lots;
   this.Sl=_sl;
   this.Tp=_tp;
   this.Profit=_profit;
}

//+---------------------------------------------------------------------------+
Order::~Order(){
}

//+---------------------------------------------------------------------------+
TradeManager::TradeManager(){
}

//+---------------------------------------------------------------------------+
TradeManager::~TradeManager(){
   this.CloseAllPositions();
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int TradeManager::GetNumActiveOrders(){
   int n_active=0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("Could not retrieve order. "+err_msg());
         continue;
      }
      if(OrderMagicNumber()==MAGICMA)
         n_active++;
   }
   return n_active;
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
Order* TradeManager::GetActiveOrder(void){
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("Could not retrieve order. "+err_msg());
         continue;
      }
      if(OrderMagicNumber()==MAGICMA){
         Order* order=new Order(
            OrderTicket(),
            OrderSymbol(),
            OrderType(),
            OrderLots(),
            0,              // WRITE_ME
            0,              // WRITE_ME
            OrderProfit()
         );
         return order;
      }
   }
   log("No active order to return!");
   return NULL;
}


//+---------------------------------------------------------------------------+
string TradeManager::ToString(){
   return "TradeManager WRITEME";
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
bool TradeManager::HasExistingPosition(string symbol, int otype){
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol()==symbol || OrderMagicNumber()!=MAGICMA)
         continue;
         
      //double price=OrderType()==OP_BUY || OrderType()=
   }
   return false;
}

//+---------------------------------------------------------------------------+
//| otype: OP_BUY,OP_SELL,OP_BUYLIMIT,OP_SELLLIMIT
//+---------------------------------------------------------------------------+
int TradeManager::OpenPosition(string symbol, int otype, double price=0.0, double lots=1.0, int tp=75, int sl=25){
   if(price==0.0)    
      price=otype==OP_BUY? Ask: otype==OP_SELL? Bid: price;
   
   int oid=OrderSend(Symbol(),otype,lots,price,3,
      otype==OP_BUY || otype==OP_BUYLIMIT? price-sl*Point*10: price+sl*Point*10,
      otype==OP_BUY || otype==OP_BUYLIMIT? price+tp*Point*10: price-tp*Point*10,
      "",MAGICMA,0,clrBlue
   );
   
   if(oid==-1){
      log("Error creating order. Reason: "+err_msg()+
          "\nOrder Symbol:"+Symbol()+", minStopLevel:"+(string)MarketInfo(Symbol(), MODE_STOPLEVEL) + 
          ", TP:"+(string)tp+", SL:"+(string)sl);
      return -1;
   }
   
   int arrow=otype==OP_BUY || otype==OP_BUYLIMIT? OBJ_ARROW_UP: OBJ_ARROW_DOWN;
   int colour=otype==OP_BUY || otype==OP_BUYLIMIT? clrBlue: clrRed;
   CreateArrow("order"+(string)oid, Symbol(), arrow, 0, colour);
   log("Opened position (Ticket "+(string)oid+")");
   return oid;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void TradeManager::ClosePosition(int ticket) {
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("Could not retrieve order. "+err_msg());
         continue;
      }
      if(OrderTicket()==ticket) {
         double price=OrderType()==OP_BUY || OrderType()==OP_BUYLIMIT? Bid : Ask;
         if(!OrderClose(OrderTicket(),OrderLots(),price,3,clrBlue))
            log("Error closing order "+(string)OrderTicket()+", Reason: "+err_msg());
         else {
            int obj=OrderType()==OP_BUY || OrderType()==OP_BUYLIMIT? OBJ_ARROW_DOWN: OBJ_ARROW_UP;
            CreateArrow((string)OrderTicket()+"_close", Symbol(),obj,0,clrRed);
            log("Closed Position (Ticket "+(string)OrderTicket()+")");
         }
      }
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void TradeManager::CloseAllPositions(){
   int n_start=OrdersTotal();
   
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("Could not retrieve order. "+err_msg());
         continue;
      }     
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
         
      double price=OrderType()==OP_BUY || OrderType()==OP_BUYLIMIT? Bid : Ask;
      
      if(!OrderClose(OrderTicket(),OrderLots(),price,3,clrBlue)){
         log("Error closing order "+(string)OrderTicket()+", Reason: "+err_msg());
      }
      else {
         int obj=OrderType()==OP_BUY || OrderType()==OP_BUYLIMIT? OBJ_ARROW_DOWN: OBJ_ARROW_UP;
         CreateArrow((string)OrderTicket()+"_close", Symbol(),obj,0,clrRed);
      }
   }
   
   int n_closed=n_start-OrdersTotal();
   log("Closed "+(string)n_closed+" positions. Remaining:"+(string)OrdersTotal());
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
double TradeManager::GetTotalProfit(bool unrealized=true){
   double profit=0.0;
   
   for(int i=0; i<OrdersTotal(); i++) {
      // MODE_TRADES (default)- order selected from trading pool(opened and pending orders),
      // MODE_HISTORY - order selected from history pool (closed and canceled order).
      int pool=unrealized? MODE_TRADES: MODE_HISTORY;
      if(!OrderSelect(i, SELECT_BY_POS, pool)){
         log("Could not retrieve order. "+err_msg());
         continue;
      }
      if(OrderMagicNumber()!=MAGICMA)
         continue;
      
      profit+=OrderProfit();
      OrderPrint();   // Dumps to MT4 Terminal log
   }
   //log((string)OrdersTotal()+" active orders, $"+(string)profit+" profit.");
   return profit;
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
string TradeManager::GetHistoryStats(){
   // retrieving info from trade history 
   int i,hstTotal=OrdersHistoryTotal(); 
   for(i=0;i<hstTotal;i++){ 
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==false){ 
         Print("Access to history failed with error (",GetLastError(),")"); 
         break; 
      } 
   }
   return "";
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
string TradeManager::GetAcctStats(){
   log("Account: "+AccountInfoString(ACCOUNT_NAME)+", Broker: "+AccountInfoString(ACCOUNT_COMPANY)); 
   log("Server: "+AccountInfoString(ACCOUNT_SERVER)); 
   log("Deposit currency = ",AccountInfoString(ACCOUNT_CURRENCY));
   return "";
}
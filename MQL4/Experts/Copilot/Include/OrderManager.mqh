//+---------------------------------------------------------------------------+
//|                                                  Include/OrderManager.mq4 |      
//+---------------------------------------------------------------------------+
#property strict

#include "Logging.mqh"
#include "Draw.mqh"

#define MAGICMA         9516235  
#define LOTS            1.0
#define TAKE_PROFIT     1000
#define STOP_LOSS       100

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
//|****************************** OrderManager Class **************************
//----------------------------------------------------------------------------+
class OrderManager {
   public:
      OrderManager();
      ~OrderManager();
      int GetNumActiveOrders();
      Order* GetActiveOrder();
      double GetTotalProfit(bool unrealized=true);
      string GetHistoryStats();
      string GetAcctStats();
      void GetAssetStats();
      string ToString();
      int OpenPosition(string symbol, int otype, double price=0.0, double lots=1.0, int tp=TAKE_PROFIT, int sl=STOP_LOSS);
      int ClosePosition(int ticket);
      void CloseAllPositions();
      void UpdateClosedPositions();
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
OrderManager::OrderManager(){
}

//+---------------------------------------------------------------------------+
OrderManager::~OrderManager(){
   this.CloseAllPositions();
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int OrderManager::GetNumActiveOrders(){
   int n_active=0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("GetNumActiveOrders(): Could not retrieve order. "+err_msg());
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
Order* OrderManager::GetActiveOrder(void){
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("GetActiveOrder(): Could not retrieve order. "+err_msg());
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
string OrderManager::ToString(){
   return "OrderManager WRITEME";
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
bool OrderManager::HasExistingPosition(string symbol, int otype){
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
int OrderManager::OpenPosition(string symbol, int otype, double price=0.0, double lots=1.0, int tp=TAKE_PROFIT, int sl=STOP_LOSS){
   if(price==0.0)    
      price=otype==OP_BUY? Ask: otype==OP_SELL? Bid: price;
   
   int ticket=OrderSend(Symbol(),otype,lots,price,3,
      otype==OP_BUY || otype==OP_BUYLIMIT? price-sl*Point*10: price+sl*Point*10,
      otype==OP_BUY || otype==OP_BUYLIMIT? price+tp*Point*10: price-tp*Point*10,
      "",MAGICMA,0,clrBlue
   );
   
   if(ticket==-1){
      log("Error creating order. Reason: "+err_msg()+
          "\nOrder Symbol:"+Symbol()+", minStopLevel:"+(string)MarketInfo(Symbol(), MODE_STOPLEVEL) + 
          ", TP:"+(string)tp+", SL:"+(string)sl);
      return -1;
   }
   
   int arrow=otype==OP_BUY || otype==OP_BUYLIMIT? OBJ_ARROW_UP: OBJ_ARROW_DOWN;
   int colour=otype==OP_BUY || otype==OP_BUYLIMIT? clrBlue: clrRed;
   CreateArrow("order"+(string)ticket, Symbol(), arrow, 0, colour);
   log("Opened position (Ticket "+(string)ticket+")");
   return ticket;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int OrderManager::ClosePosition(int ticket) {
   if(ticket<0)
      return -1;
      
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)){
      log("ClosePosition(): Could not retrieve order. "+err_msg());
      return -1;
   }

   double price=OrderType()==OP_BUY || OrderType()==OP_BUYLIMIT? Bid : Ask;
   color c=OrderType()==OP_BUY || OrderType()==OP_BUYLIMIT? clrRed : clrBlue;
   int arrow=OrderType()==OP_BUY || OrderType()==OP_BUYLIMIT? OBJ_ARROW_DOWN: OBJ_ARROW_UP;
   
   if(!OrderClose(OrderTicket(),OrderLots(),price,3,c)){
      log("Error closing order "+(string)OrderTicket()+", Reason: "+err_msg());
      return -1;
   }
   
   CreateArrow((string)OrderTicket()+"_close", Symbol(),arrow,0,c);
   log("Closed Position (Ticket "+(string)OrderTicket()+")");
   return 0;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void OrderManager::CloseAllPositions(){
   int n_start=OrdersTotal();
   
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("CloseAllPositions(): Could not retrieve order. "+err_msg());
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
void OrderManager::UpdateClosedPositions() {
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      else if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
      
      // Check if StopLoss was hit 
      if(OrderStopLoss()==OrderClosePrice() || StringFind(OrderComment(), "[sl]", 0)!=-1){  
         if(ObjectFind((string)OrderTicket()+"_SL")==-1){
            CreateArrow(
               (string)OrderTicket()+"_SL",
               Symbol(),
               OBJ_ARROW_STOP,
               iBarShift(Symbol(),0,OrderCloseTime()),
               clrRed
            );
            log("Order #"+(string)OrderTicket()+" hit SL!");
         }
      }
      // Check if TakeProfit was hit
      else if(OrderProfit()==OrderClosePrice() || StringFind(OrderComment(), "[tp]", 0)!=-1){
         if(ObjectFind((string)OrderTicket()+"_TP")==-1){
            CreateArrow(
               (string)OrderTicket()+"_TP",
               Symbol(),
               OBJ_ARROW_CHECK,
               iBarShift(Symbol(),0,OrderCloseTime()),
               clrGreen
            );
            log("Order #"+(string)OrderTicket()+" hit TP!");
         }
      }
   }
}


//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
double OrderManager::GetTotalProfit(bool unrealized=true){
   double profit=0.0;
   
   for(int i=0; i<OrdersTotal(); i++) {
      // MODE_TRADES (default)- order selected from trading pool(opened and pending orders),
      // MODE_HISTORY - order selected from history pool (closed and canceled order).
      //int pool=unrealized? MODE_TRADES: MODE_HISTORY;
      if(!OrderSelect(i, SELECT_BY_POS, unrealized? MODE_TRADES: MODE_HISTORY)){
         log("GetTotalProfit(): Could not retrieve order. "+err_msg());
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
string OrderManager::GetHistoryStats(){
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
string OrderManager::GetAcctStats(){
   log("***** Trading Account *****");
   log("Account: "+AccountInfoString(ACCOUNT_NAME));
   log("Broker: "+AccountInfoString(ACCOUNT_COMPANY)); 
   log("Server: "+AccountInfoString(ACCOUNT_SERVER)); 
   //log("Deposit currency = ",AccountInfoString(ACCOUNT_CURRENCY));
   log("");
   return "";
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
void OrderManager::GetAssetStats(){
   log("***** Asset Info *****");
   log("Symbol: "+Symbol());
   log("Desc: "+SymbolInfoString(Symbol(),SYMBOL_DESCRIPTION));
   log("Point: "+(string)MarketInfo(Symbol(),MODE_POINT));
   log("Digits: "+(string)MarketInfo(Symbol(),MODE_DIGITS));
   log("Bid: "+(string)MarketInfo(Symbol(),MODE_BID));
   log("Ask: "+(string)MarketInfo(Symbol(),MODE_ASK));
   log("Spread: "+(string)MarketInfo(Symbol(),MODE_SPREAD));
   log("Min Lot: "+(string)MarketInfo(Symbol(),MODE_MINLOT));
   log("Trading Enabled: "+(MarketInfo(Symbol(),MODE_TRADEALLOWED)==1? "YES": "NO"));
   log("");
}
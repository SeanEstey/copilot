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

string OrderTypes[6] = {"BUY", "SELL", "BUYLIMIT", "BUYSTOP", "SELLLIMIT", "SELLSTOP"};


//----------------------------------------------------------------------------+
//|****************************** OrderManager Class **************************
//----------------------------------------------------------------------------+
class OrderManager {
   protected:
      int Orders[], SLOrders[], TPOrders[];
      int nTrades, nPositions, nStops, nTakeProfit;
      string ntrades_lbl;
      string npos_lbl;
   public:
      OrderManager();
      ~OrderManager();
      int OpenPosition(string symbol, int otype, double price=0.0, double lots=1.0, int tp=75, int sl=25);
      void ClosePosition(int ticket);
      void CloseAllPositions();
      bool HasExistingPosition(string symbol, int otype);
      int GetNumActiveOrders();
      double GetProfit();
      string GetHistoryStats();
      string GetAcctStats();
      string ToString();
};


//----------------------------------------------------------------------------+
//|**************************** Method Definitions ****************************
//----------------------------------------------------------------------------+


//+---------------------------------------------------------------------------+
OrderManager::OrderManager(){
   ArrayResize(this.Orders,1);
   ArrayResize(this.SLOrders,1);
   ArrayResize(this.TPOrders,1);
   this.ntrades_lbl="trades";
   this.npos_lbl="positions";
}

//+---------------------------------------------------------------------------+
OrderManager::~OrderManager(){
   this.CloseAllPositions();
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
int OrderManager::OpenPosition(string symbol, int otype, double price=0.0, double lots=1.0, int tp=75, int sl=25){
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
   
   CreateArrow("order"+(string)oid, Symbol(), OBJ_ARROW_UP, 0, clrBlue);
   this.Orders[ArraySize(this.Orders)-1] = oid;
   ArraySort(this.Orders, WHOLE_ARRAY, 0, MODE_ASCEND);
   ArrayResize(this.Orders,ArraySize(this.Orders)+1);
   this.nTrades++;
   this.nPositions++;
   log("Order ID: "+(string)oid);   
   return oid;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void OrderManager::ClosePosition(int ticket) {
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
            this.nTrades++;
            this.nPositions--;
         }
      }
   }
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void OrderManager::CloseAllPositions(){
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
         this.nTrades++;
         this.nPositions--;
      }
   }
   
   int n_closed=n_start-OrdersTotal();
   log("Closed "+(string)n_closed+" positions. Remaining:"+(string)OrdersTotal());
}


//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int OrderManager::GetNumActiveOrders(){
      int n_active=0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("Could not retrieve order. "+err_msg());
         continue;
      }
      if(OrderMagicNumber()==MAGICMA)
         n_active++;
   }
   
   log((string)n_active+" active orders.");
   return n_active;
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
double OrderManager::GetProfit(){
   double profit=0.0;
   
   for(int i=0; i<OrdersTotal(); i++) {
      // MODE_TRADES (default)- order selected from trading pool(opened and pending orders),
      // MODE_HISTORY - order selected from history pool (closed and canceled order).
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         log("Could not retrieve order. "+err_msg());
         continue;
      }
      if(OrderMagicNumber()!=MAGICMA)
         continue;
      
      profit+=OrderProfit();
      OrderPrint();   // Dumps to MT4 Terminal log
   }
   log((string)OrdersTotal()+" active orders, $"+(string)profit+" profit.");
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
   log("*******************************************************");
   log("Terminal Company: "+TerminalCompany()+", Name: "+TerminalName());
   log("The name of the broker = ",AccountInfoString(ACCOUNT_COMPANY)); 
   log("Deposit currency = ",AccountInfoString(ACCOUNT_CURRENCY)); 
   log("Client name = ",AccountInfoString(ACCOUNT_NAME)); 
   log("The name of the trade server = ",AccountInfoString(ACCOUNT_SERVER)); 
   log("*******************************************************");
   return "";
}
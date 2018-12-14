//+---------------------------------------------------------------------------+
//|                                                             FX/Orders.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict

//--- Custom includes
#include <FX/Logging.mqh>
#include <FX/Draw.mqh>

double Lots             = 1.0;
int    TakeProfit       = 75;   
int    StopLoss         = 25;

//--- Globals
int nTrades=0;
int nPositions=0;
int nStops=0;
int nTakeProfit=0;
string ntrades_lbl = "trades";
string npos_lbl = "positions";
string OrderTypes[6] = {"BUY", "SELL", "BUYLIMIT", "BUYSTOP", "SELLLIMIT", "SELLSTOP"};
int SLOrders[];
int TPOrders[];
int Orders[];
string ObjList[];

double GetLots() {return Lots;}
int CalculateCurrentOrders(string symbol) {return 1;}


//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
void CheckClosedOrders() {
   int ticket;
   for(int i=0; i<ArraySize(Orders); i++) {
      ticket=Orders[i];
      
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         continue;
      else if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
      
      // Check if StopLoss was hit 
      if(OrderStopLoss()==OrderClosePrice() || StringFind(OrderComment(), "[sl]", 0)!=-1){  
         if(SLOrders[ArrayBsearch(SLOrders, ticket)] != ticket) {
            log("Order #"+(string)ticket+" hit SL!");
            CreateArrow((string)ticket+"_SL", Symbol(), OBJ_ARROW_STOP,
               iBarShift(Symbol(),0,OrderCloseTime()), clrRed, ObjList);
            ArrayResize(SLOrders,ArraySize(SLOrders)+1);
            SLOrders[ArraySize(SLOrders)-1] = ticket;
            ArraySort(SLOrders, WHOLE_ARRAY, 0, MODE_ASCEND);
            
            nStops++;
            nPositions--;
         }
      }
      // Check if TakeProfit was hit
      else if(OrderProfit()==OrderClosePrice() || StringFind(OrderComment(), "[tp]", 0)!=-1){
         if(TPOrders[ArrayBsearch(TPOrders, ticket)] != ticket) {
            CreateArrow((string)ticket+"_TP",Symbol(),OBJ_ARROW_CHECK,
               iBarShift(Symbol(),0,OrderCloseTime()), clrGreen, ObjList);
            ArrayResize(TPOrders,ArraySize(TPOrders)+1);
            TPOrders[ArraySize(TPOrders)-1] = ticket;
            ArraySort(TPOrders, WHOLE_ARRAY, 0, MODE_ASCEND);
            
            nTakeProfit++;
            nPositions--;   
            
            log("Order #"+(string)ticket+" hit TP!");
         }
      }
   }
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
void UpdateOpenPendingOrders() {
   int res, action;
   
   for(int i=0; i<OrdersTotal(); i++) {
      // Load next open/pending order
      bool is_selected = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);      
      if(!is_selected) {
         log("Could not retrieve order. "+err_msg());
         continue;
      }     
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGICMA)
         continue;
         
      action = GetExitSignal();
      
      if(action==0)
         continue;
      else if(action == 1) {
         res=OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrBlue);
         CreateArrow((string)OrderTicket()+"_close", Symbol(), OBJ_ARROW_UP,0,clrRed, ObjList);
      }
      else if(action == -1) {
         res=OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed);
         CreateArrow((string)OrderTicket()+"_close", Symbol(), OBJ_ARROW_DOWN,0, clrBlue, ObjList);
      }
      
      if(res != 1)
         log("Error closing order "+(string)OrderTicket()+", Reason: "+err_msg());
      else {
         log("Closed "+OrderTypes[OrderType()]+" order #"+(string)OrderTicket()+
            ", Reason: StochRSI reset.");
         nTrades++;
         nPositions--;
      }
   }
}

//+---------------------------------------------------------------------------+
//| Evaluate new positions
//+---------------------------------------------------------------------------+
void CreateNewOrders() {
   int oid, type;
   double TP=0.0, SL=0.0, price=0.0;
   int signal = GetEntrySignal();
   
   if(signal==0) {
      ObjectSetString(0,ntrades_lbl,OBJPROP_TEXT,"Trades:"+(string)nTrades);
      ObjectSetString(0,npos_lbl,OBJPROP_TEXT,"Positions:"+(string)nPositions);
      return;
   }
   else if(signal==1){  // Buy   
      type=OP_BUY;
      price = Bid;
      TP = Bid + TakeProfit*Point*10;   //0.00001 * 10 = 0.0001
      SL = Bid - StopLoss*Point*10;
      oid = OrderSend(Symbol(),type,GetLots(),Ask,3,SL,TP,"",MAGICMA,0,clrBlue);
      
      CreateArrow((string)oid+"_open", Symbol(), OBJ_ARROW_UP, 0, clrBlue, ObjList);
      log("ObjList.size:"+(string)ArraySize(ObjList));
   }
   else if(signal==-1){  // Sell
      type=OP_SELL;
      price = Ask;
      TP = Ask - TakeProfit*Point*10;   //0.00001 * 10 = 0.0001
      SL = Ask + StopLoss*Point*10;
      
      oid = OrderSend(Symbol(),type,GetLots(),Bid,3,SL,TP,"",MAGICMA,0,clrRed);
      CreateArrow((string)oid+"_open", Symbol(), OBJ_ARROW_DOWN, 0, clrRed, ObjList);
   }
   else {
      log("Error creating "+(string)OrderType()+" order. Reason: "+err_msg()+
          "\nOrder Symbol:"+Symbol()+", minStopLevel:"+(string)MarketInfo(Symbol(), MODE_STOPLEVEL) + 
          ", TP:"+(string)TP+", SL:"+(string)SL);
      return;
   }
   
   Orders[ArraySize(Orders)-1] = oid;
   ArraySort(Orders, WHOLE_ARRAY, 0, MODE_ASCEND);
   ArrayResize(Orders,ArraySize(Orders)+1);
   
   nTrades++;
   nPositions++;
   log(OrderTypes[type]+" order #"+(string)oid+", Price:"+(string)price+", TP:"+(string)TP+", SL:"+(string)SL);
}
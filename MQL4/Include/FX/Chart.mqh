//+------------------------------------------------------------------+
//|                                                     FX/Chart.mqh |
//|                                       Copyright 2018, Sean Estey |
//+------------------------------------------------------------------+

#property copyright "Copyright 2018, Sean Estey"
#property strict

#include <FX/Logging.mqh>
//#include <FX/Utility.mqh>

//---String format for events passed to OnChartEvent() callback
string ChartEventNames[10]={
   "CHARTEVENT_KEYDOWN",
   "CHARTEVENT_MOUSE_MOVE",
   "CHARTEVENT_OBJECT_CREATE",
   "CHARTEVENT_OBJECT_CHANGE",
   "CHARTEVENT_OBJECT_DELETE",
   "CHARTEVENT_CLICK",
   "CHARTEVENT_OBJECT_CLICK", 
   "CHARTEVENT_OBJECT_DRAG",
   "CHARTEVENT_OBJECT_ENDEDIT",
   "CHARTEVENT_CHART_CHANGE"
   //"CHARTEVENT_CUSTOM",
   //"CHARTEVENT_CUSTOM_LAST"};
};

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int CoordsToBar(int x, int y) {
   double price=0;
   datetime dt=0;
   int window=0;
   ChartXYToTimePrice(0,x,y,window,dt,price);
   int bar=iBarShift(Symbol(),0,dt);
   return bar;
   //log("Mouse move. Xpos:"+(string)lparam+", Dt:"+(string)dt+", Price:"+(string)price);
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int ScalePeriod(int period){
   if(PERIOD_CURRENT > PERIOD_D1) {
      log("Cannot scale period higher than Daily!");
      return -1;
   }
   int scaled=period*(PERIOD_D1/Period());
   
   if(scaled >= Bars) {
      log("ScalePeriod(): period "+(string)period+" cannot be scaled down to "+(string)Period()+
         " because it exceeds total Bars ("+(string)+Bars+").");
      return -1;
   }
   return scaled;
}


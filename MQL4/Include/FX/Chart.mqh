//+------------------------------------------------------------------+
//|                                                     FX/Chart.mqh |
//|                                       Copyright 2018, Sean Estey |
//+------------------------------------------------------------------+

#property copyright "Copyright 2018, Sean Estey"
#property strict

#include <FX/Logging.mqh>
#include <FX/Draw.mqh>

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

//+----------------------------------------------------------------------------+
//+----------------------------------------------------------------------------+
bool NewBar() {
    static datetime lastbar;
    datetime curbar = Time[0];  
    if(lastbar != curbar) {
       lastbar=curbar;
       return true;
    }
    else
      return false;
}

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

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
void DrawFixedRanges(string symbol, ENUM_TIMEFRAMES tf, int offset, int count,
                color clr, string& objs[]){
   datetime start_dt,end_dt;
   
   for(int i=offset+count-1; i>0; i--) {
      start_dt=iTime(symbol, tf,offset+i);
      if(i==1)
         end_dt = TimeCurrent();
      else
         end_dt=iTime(symbol, tf,offset+i-1);
      
      double high = iHigh(symbol, tf, offset+i);
      double low = iLow(symbol, tf, offset+i);
  
      string name1="high_line__p"+(string)tf+"_"+(string)(offset+i);
      string name2="low_line_p"+(string)tf+"_"+(string)(offset+i);
      
      CreateTrendline(name1,start_dt,high,end_dt,high,objs,0,clr,0,1);
      CreateTrendline(name2,start_dt,low,end_dt,low,objs,0, clr,0,1);
      
      //log("Low/High levels for "+TimeToStr(start_dt,TIME_DATE)+" to "+
      //   TimeToStr(end_dt,TIME_DATE)+". High:"+(string)high+", Low:"+(string)low);
   }
}

//-----------------------------------------------------------------------------+
//+********************************** UNITS ***********************************+
//-----------------------------------------------------------------------------+


//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
double ToPips(double price) {
   double dig=MarketInfo(Symbol(),MODE_DIGITS);
   double pts=MarketInfo(Symbol(),MODE_POINT);
   return price/pts;
}  

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
string ToPipsStr(double price, int decimals=0) {
   double dig=MarketInfo(Symbol(),MODE_DIGITS);
   double pts=MarketInfo(Symbol(),MODE_POINT);
   return DoubleToStr(price/pts,decimals);
}
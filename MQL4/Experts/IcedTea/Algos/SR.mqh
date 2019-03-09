//+---------------------------------------------------------------------------+
//|                                                      Include/Algos/SR.mqh |      
//+---------------------------------------------------------------------------+
#property strict

#include "../Include//Logging.mqh"
#include "../Include//Draw.mqh"
#include "../Include//Chart.mqh"

enum Signals {NONE, OPEN_LONG, CLOSE_LONG, OPEN_SHORT, CLOSE_SHORT};


//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int ScanLevels(int nbars){
   double dig=MarketInfo(Symbol(),MODE_DIGITS);
   double pts=MarketInfo(Symbol(),MODE_POINT);
   double low=iLow(NULL,0,iLowest(NULL,0,MODE_LOW,nbars,0));
   double high=iHigh(NULL,0,iHighest(NULL,0,MODE_HIGH,nbars,0));
   int height=ToPips(high-low);
   int firstbar=ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR);
   int barwidth=ChartGetInteger(0,CHART_WIDTH_IN_BARS);
   int lscanbar=firstbar-barwidth+nbars+1;
   int rscanbar=firstbar-barwidth+2;
   
   debuglog("ScanLevels() Symbol:" +Symbol()+", ScanWidth:" +(string)nbars+"\n"+
      ", High:"+DoubleToStr(high) +", Low:"+DoubleToStr(low)+", PipsHeight:"+(string)height+"\n"+
      ", StartBar:"+(string)lscanbar+", EndBar:"+(string)rscanbar);
   
   int maxwicks=-1;
   for(double level=low; level<=high; level+=pts){
      int nwicks=CountCandleWicks(level,lscanbar,rscanbar,true);
      if(nwicks > maxwicks){
         maxwicks=nwicks;
         debuglog("Significant Level: "+DoubleToStr(level,dig)+", nWicks:"+(string)nwicks);
      }
   }
   return 1;
}

//+---------------------------------------------------------------------------+
//|
//+---------------------------------------------------------------------------+
bool InRange(double p, double r, double spread) {
   return p>=(r-spread) && p<=(r+spread)? true: false;
}

//+---------------------------------------------------------------------------+
//+---------------------------------------------------------------------------+
int CountCandleWicks(double p, int bar1, int bar2, bool ends_only=false){
   double spread=MarketInfo(Symbol(),MODE_POINT)*SPREAD_MULT;
   int n=0;
   
   for(int i=bar2; i<bar1; i++){
      if(ends_only==true && InRange(p,iHigh(Symbol(),0,i),spread) || InRange(p,iLow(Symbol(),0,i),spread))
         n++;
      else{
         double lowerbody=iClose(Symbol(),0,i)>iOpen(Symbol(),0,i) ? iClose(Symbol(),0,i) : iOpen(Symbol(),0,i);
         double upperbody=iOpen(Symbol(),0,i)<iClose(Symbol(),0,i) ? iOpen(Symbol(),0,i) : iClose(Symbol(),0,i); 
         if((p<=iHigh(Symbol(),0,i) && p>upperbody) || (p>=iLow(Symbol(),0,i) && p<lowerbody))
            n++;
      }
   }
   //debuglog("NumCandleWick collisions at "+DoubleToStr(level,3)+": "+(string)n);
   return n;
}

//+---------------------------------------------------------------------------+
//+---------------------------------------------------------------------------+
int NumCandleBodies(double p, int bar1, int bar2, bool ends_only=false){
   double spread=MarketInfo(Symbol(),MODE_POINT)*SPREAD_MULT;
   int n=0;
   
   for(int i=bar2; i<bar1; i++){
      if(ends_only==true && InRange(p,iOpen(Symbol(),0,i),spread) || InRange(p,iClose(Symbol(),0,i),spread))
         n++;
      else {
         
         double lowerbody=iClose(Symbol(),0,i)>iOpen(Symbol(),0,i) ? iClose(Symbol(),0,i) : iOpen(Symbol(),0,i);
         double upperbody=iOpen(Symbol(),0,i)<iClose(Symbol(),0,i) ? iOpen(Symbol(),0,i) : iClose(Symbol(),0,i); 
         if(p<=iHigh(Symbol(),0,i) && p>upperbody || p>=iLow(Symbol(),0,i) && p<lowerbody)
            n++;
      }
   }   
   return n;
}

//+---------------------------------------------------------------------------+
//+---------------------------------------------------------------------------+
int Intersects(double price, int bar1, int bar2) {
   if(bar1<=bar2){
      log("Intersects() bar1 must be greater than bar2");
      return -1;
   }
   int n_touches=0;
   int n_bars=Bars(Symbol(),0,iTime(NULL,0,bar1),iTime(NULL,0,bar2));
   datetime dt = iTime(NULL,0,bar1);
   
   debuglog("Intersects() P:"+DoubleToStr(price,3));
   
   for(int i=0; i<n_bars; i++){
      int shift=iBarShift(Symbol(),0,dt);
      if(price<=iHigh(Symbol(),0,shift) && price>=iLow(Symbol(),0,shift)) {
         n_touches++;
         debuglog("Bar "+(string)shift+": found intersection. Touches:"+(string)n_touches);
      }
      dt+=PeriodSeconds();
   }
   return n_touches;
}

//+------------------------------------------------------------------+
//| Returns: Signal enum
//+------------------------------------------------------------------+
int GetSignal(){
   return 1;
}
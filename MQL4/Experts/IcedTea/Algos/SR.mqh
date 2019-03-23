//+---------------------------------------------------------------------------+
//|                                                      Include/Algos/SR.mqh |      
//+---------------------------------------------------------------------------+
#property strict

#include "../Include//Logging.mqh"
#include "../Include//Draw.mqh"
#include "../Include//Chart.mqh"
#include "../Include//Graph.mqh"
#include "../Include//SwingPoints.mqh"

enum Signals {NONE, OPEN_LONG, CLOSE_LONG, OPEN_SHORT, CLOSE_SHORT};

#define TEXT_OFFSET     0
#define LVL_GROUP_DIST  100
#define SR_LINE_COLOR   clrRed
#define SR_LINE_WIDTH   2
#define SR_ZONE_COLOR   clrLightPink

enum CandleRegion {ANY_REGION, WICK_AREA, LOW_OR_HIGH, BODY_AREA, OPEN_OR_CLOSE};       //OHLC
enum CollisionVector {FROM_ANYWHERE, FROM_ABOVE, FROM_BELOW};
enum MatchType {COLLISION, CLOSED_BEYOND};

//+---------------------------------------------------------------------------+
//| Draws SR level trendlines/zones + hit rate stats                          |
//+---------------------------------------------------------------------------+
int GenerateSR(SwingGraph* Swings){
   double levels[][2];        // 2D-array, each element containing array of {price,nodeIndex}
   ArrayResize(levels,Swings.NodeCount());
   
   for(int i=0; i<Swings.NodeCount(); i++){
      SwingPoint* sp=Swings.GetNode(i);
      if(sp.MyLevel!=LONG)
         continue;
      
      levels[i][0]=sp.GetValue();
      levels[i][1]=i;
   }
   ArraySort(levels,WHOLE_ARRAY,0,MODE_ASCEND); // Sort by price levels
   
   // Group + Draw SR level trendlines/zones
   for(int i=0; i<ArrayRange(levels,0); i++){
      double group[];
      
      if(levels[i][0]==0.0)
         continue;
      appendDoubleArray(group,levels[i][1]);
         
      log("levels["+(string)i+"]: "+DoubleToStr(levels[i][0]));
      
      // Group levels with close proximity
      for(int j=i+1; j<ArrayRange(levels,0); j++){
         if(levels[j][0]==0)
            continue;
         if(MathAbs(ToPips(levels[i][0])-ToPips(levels[j][0])) < LVL_GROUP_DIST){
            appendDoubleArray(group,levels[j][1]);
            levels[j][0]=0;
         }
      }
      
      // Evaluate historic hit rate of SR level
      SwingPoint* sp=Swings.GetNode(group[0]);
      double p=sp.Type==LOW? sp.L: sp.H;
      int s_misses=CountLevelHits(p, sp.Shift, 1, WICK_AREA, CLOSED_BEYOND, FROM_ABOVE);
      int r_misses=CountLevelHits(p, sp.Shift, 1, WICK_AREA, CLOSED_BEYOND, FROM_BELOW);
      int s_hits=CountLevelHits(p, sp.Shift, 1, WICK_AREA, COLLISION, FROM_ABOVE);
      int r_hits=CountLevelHits(p, sp.Shift, 1, WICK_AREA, COLLISION, FROM_BELOW);
      
      // Draw ungrouped levels as trendline
      if(ArraySize(group)==1){
         SwingPoint* _sp=Swings.GetNode(group[0]);
         CreateTrendline("SR_"+(string)i,iTime(NULL,0,0),
            _sp.GetValue(),iTime(NULL,0,_sp.Shift),_sp.GetValue(),0,
            SR_LINE_COLOR,STYLE_SOLID,SR_LINE_WIDTH,
            true,false,true,0);
      }
      // Draw grouped levels as rectangular zone
      else if(ArraySize(group)>1){
         double prices[];
         datetime dt[];
         for(int k=0; k<ArraySize(group); k++){
            SwingPoint* _sp=Swings.GetNode(group[k]);
            appendDoubleArray(prices,_sp.GetValue());
            appendDtArray(dt,_sp.DT);
         }
         CreateRect((string)group[0]+"_rect", 
            dt[ArrayMinimum(dt,WHOLE_ARRAY,0)],
            prices[ArrayMaximum(prices,WHOLE_ARRAY,0)],
            iTime(NULL,0,0),
            prices[ArrayMinimum(prices,WHOLE_ARRAY,0)],
            0,0,SR_ZONE_COLOR,STYLE_SOLID,1,true,true,true,true,0
         ); 
      }
      
      // Print SR level label
      string lbl="Misses:"+(string)(s_misses+r_misses)+", Hits:"+(string)(s_hits+r_hits);
      CreateText("SR_lbl_"+(string)i,lbl,
         0,ANCHOR_LOWER,p,0,0,0,"Arial",8,clrBlack,0.0,true,false,true,0);
   }
   return 1;
}

//+---------------------------------------------------------------------------+
//+---------------------------------------------------------------------------+
int CountLevelHits(double level, int bar1, int bar2, CandleRegion region=ANY_REGION, MatchType matchtype=COLLISION, CollisionVector vector=FROM_ANYWHERE){
   double spread=MarketInfo(Symbol(),MODE_POINT)*SPREAD_MULT;
   int n=0;
   
   for(int i=bar2; i<bar1; i++){
      // Test for candles with regions that have hit our level
      if(matchtype==COLLISION){
         if(vector==FROM_ABOVE && iOpen(NULL,0,i)<=level)
            continue;
         else if(vector==FROM_BELOW && iOpen(NULL,0,i)>=level)
            continue;
         
         if(region==OPEN_OR_CLOSE){
            if(InRange(level,iOpen(Symbol(),0,i),spread) || InRange(level,iClose(Symbol(),0,i),spread))
               n++;
         }
         else if(region==LOW_OR_HIGH){
            if(InRange(level,iHigh(Symbol(),0,i),spread) || InRange(level,iLow(Symbol(),0,i),spread))
               n++;
         }
         else if(region==BODY_AREA){
            if(level>=MathMin(iOpen(NULL,0,i),iClose(NULL,0,i)) && level<=MathMax(iOpen(NULL,0,i),iClose(NULL,0,i)))
               n++;
         }
         else if(region==WICK_AREA){
            if((level>=MathMax(iOpen(NULL,0,i),iClose(NULL,0,i)) && level<=iHigh(NULL,0,i)) ||
               (level<=MathMin(iOpen(NULL,0,i),iClose(NULL,0,i)) && level>=iLow(NULL,0,i)))
               n++;
         }
         else if(region==ANY_REGION){
            if(level>=iLow(NULL,0,i) && level<=iHigh(NULL,0,i))
               n++;
         }
      }
      // Test for candles that opened above/below level and closed on opposite side.
      else if(matchtype==CLOSED_BEYOND){
         if(vector==FROM_BELOW && iOpen(NULL,0,i)<level && iClose(NULL,0,i)>level)
            n++;
         else if(vector==FROM_ABOVE && iOpen(NULL,0,i)>level && iClose(NULL,0,i)<level)
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
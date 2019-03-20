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
#define LVL_GROUP_DIST  400


enum CandleRegion {ANY_REGION, WICK_AREA, LOW_OR_HIGH, BODY_AREA, OPEN_OR_CLOSE};       //OHLC
enum CollisionVector {FROM_ANYWHERE, FROM_ABOVE, FROM_BELOW};
enum MatchType {COLLISION, CLOSED_BEYOND};


//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int GenerateSR(SwingGraph* Swings){
   int srnodes[];
   double levels[];
   
   for(int i=0; i<Swings.NodeCount(); i++){
      SwingPoint* sp=Swings.GetNode(i);
      if(sp.MyLevel==LONG){
         appendIntArray(srnodes,i);
         appendDoubleArray(levels,sp.GetValue());
      }
   }
   
   ArraySort(levels,WHOLE_ARRAY,0,MODE_ASCEND);
   
   for(int i=0; i<ArraySize(levels); i++){
      double grouplvls[];
      
      if(levels[i]==0)
         continue;
      
      appendDoubleArray(grouplvls,levels[i]);
      
      for(int j=i+1; j<ArraySize(levels); j++){
         if(levels[j]==0)
            continue;
         if(MathAbs(ToPips(levels[i])-ToPips(levels[j])) < LVL_GROUP_DIST){
            appendDoubleArray(grouplvls,levels[j]);
            levels[j]=0;
         }
      }
    
      
      if(ArraySize(grouplvls)==1){
         CreateTrendline("SR_"+(string)i,1000,grouplvls[0],iTime(NULL,0,0),grouplvls[0],0,clrRed,STYLE_SOLID,1,true,false,true,0);   
      //   CreateRect((string)grouplvls[0]+"_rect",
      //      iTime(NULL,0,1000),grouplvls[0],iTime(NULL,0,0),grouplvls[0]+(Point*5),0,0,clrRed,STYLE_SOLID,1,true,true,true,true,0); 
      }
      else if(ArraySize(grouplvls)>1){
         ArraySort(grouplvls,WHOLE_ARRAY,0,MODE_ASCEND);
         CreateRect((string)grouplvls[0]+"_rect",
            iTime(NULL,0,1000),grouplvls[0],iTime(NULL,0,0),grouplvls[ArraySize(grouplvls)-1],0,0,clrLightPink,STYLE_SOLID,1,true,true,true,true,0); 
      }
      ArrayResize(grouplvls,1);
   }
   
   for(int i=0; i<ArraySize(srnodes); i++){
      int srgroup[];
      SwingPoint* sp_a=(SwingPoint*)Swings.GetNode(srnodes[i]);
   
      for(int j=0; j<ArraySize(srnodes); j++){
         if(i==j)
            continue;
         SwingPoint* sp_b=(SwingPoint*)Swings.GetNode(srnodes[j]);
         double dist=MathAbs(ToPips(sp_a.GetValue())-ToPips(sp_b.GetValue()));
         
         if(dist<100)
            appendIntArray(srgroup,j);      
      }
   }
      
   // log("Bar "+(string)sp_a.Shift+" - Bar "+(string)sp_b.Shift+" height: "+DoubleToStr(MathAbs(a-b),0));
   
   for(int i=0; i<ArraySize(srnodes); i++){
      SwingPoint* sp=Swings.GetNode(srnodes[i]);
      double p=sp.Type==LOW? sp.L: sp.H;
      string lbl="";
      bool draw=false;
      
      int n_ignored=CountLevelHits(p, sp.Shift, 1, WICK_AREA, CLOSED_BEYOND, FROM_ABOVE);
      n_ignored+=CountLevelHits(p, sp.Shift, 1, WICK_AREA, CLOSED_BEYOND, FROM_BELOW);
      int n_res_retests=CountLevelHits(p, sp.Shift, 1, WICK_AREA, COLLISION, FROM_BELOW);
      int n_sup_retests=CountLevelHits(p, sp.Shift, 1, WICK_AREA, COLLISION, FROM_ABOVE);
        
      // Untested?
      if(n_ignored==0 && n_res_retests==0 && n_sup_retests==0){
         lbl+="Untested ";
         draw=true;
      }
      
      // Test if level has been flipped from R-->S (no down candles from above have broken below)
      if(sp.Type==HIGH){
         draw=true;
         /*int nflips=CountLevelHits(p, sp.Shift, 1, WICK_AREA, COLLISION, FROM_ABOVE);
         int nbroken=CountLevelHits(p, sp.Shift, 1, WICK_AREA, CLOSED_BEYOND, FROM_ABOVE);
         if(nflips>0 && nbroken==0){
            CreateTrendline("SR_"+(string)i, sp.DT,p,iTime(NULL,0,0),p,0,clrRed,STYLE_SOLID,3,true,false,true,0);
            CreateText("SR_lbl_"+(string)i,"SR Flip. Tests: "+(string)nflips,5,ANCHOR_LOWER,p,iTime(NULL,0,TEXT_OFFSET),0,0,"Arial",8,clrBlack,0.0,true,false,true,0);
         }*/
      }
      // Test if level has been flipped from S-->R (no up candles from below have broken above)
      else if(sp.Type==LOW){
         draw=true;
         /*
         int nflips=CountLevelHits(p, sp.Shift, 1, WICK_AREA, COLLISION, FROM_BELOW);
         int nbroken=CountLevelHits(p, sp.Shift, 1, WICK_AREA, CLOSED_BEYOND, FROM_BELOW);
         if(nflips>0 && nbroken==0){
            CreateTrendline("SR_"+(string)i, sp.DT,p,iTime(NULL,0,0),p,0,clrRed,STYLE_SOLID,3,true,false,true,0);
            CreateText("SR_lbl_"+(string)i, "SR Flip. Tests: "+(string)nflips,
               5,ANCHOR_LOWER,p,iTime(NULL,0,TEXT_OFFSET),0,0,"Arial",8,clrBlack,0.0,true,false,true,0);
         }*/
      }
      
      if(draw){
         lbl+=sp.GetValue()<iClose(NULL,0,0)?"Support. ": "Resistance. ";
         lbl+=" Ignored:"+(string)n_ignored+", Tests:"+(string)(n_sup_retests+n_res_retests);
         //CreateTrendline("SR_"+(string)i,sp.DT,p,iTime(NULL,0,0),p,0,clrBlack,STYLE_SOLID,3,true,false,true,0);   
         CreateText("SR_lbl_"+(string)i,lbl,0,ANCHOR_LOWER,p,0,0,0,"Arial",8,clrBlack,0.0,true,false,true,0);
      }
      
      log("Level: "+DoubleToStr(p,3)+". "+lbl);
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
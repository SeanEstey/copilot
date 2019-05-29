//+---------------------------------------------------------------------------+
//|                                                      Include/SD.mqh       |      
//+---------------------------------------------------------------------------+
#property strict

#include "../Include//Logging.mqh"
#include "../Include//Draw.mqh"
#include "../Include//Chart.mqh"
#include "../Include//Graph.mqh"
#include "../Include//SwingPoints.mqh"
#include "../Include//OrderManager.mqh"

#define TEXT_OFFSET     0
#define LVL_GROUP_DIST  100
#define SR_LINE_COLOR   clrRed
#define SR_LINE_WIDTH   2
#define SR_ZONE_COLOR   clrLightPink

enum Signals {NONE, OPEN_LONG, CLOSE_LONG, OPEN_SHORT, CLOSE_SHORT};
enum CandleRegion {ANY_REGION, WICK_AREA, LOW_OR_HIGH, BODY_AREA, OPEN_OR_CLOSE};
enum CollisionVector {FROM_ANYWHERE, FROM_ABOVE, FROM_BELOW};
enum MatchType {COLLISION, CLOSED_BEYOND};

//+----------------------------------------------------------------------------+
//| 
//+----------------------------------------------------------------------------+
class Impulse {
   public:
      // Price swing properties
      int direction;    // 1:up, -1:down, 0:none
      int start_ibar;
      int end_ibar;
      int chainlen;
      int ob_ibar;
      datetime startdt;
      datetime enddt;
      double height;
      double n_deviations;
   public:
      Impulse(int dir, int startbar, int endbar, int len, int obibar, datetime dt1, datetime dt2, double ht, double ndev);
      ~Impulse();
};


//+----------------------------------------------------------------------------+
//| 
//+----------------------------------------------------------------------------+
class SDZone {
   public:
      double price;
      int shift;
      string symbol;
      string name;
      string lblname;
      int tf;
      int n_hits;
      int n_misses;
   public:
      SDZone(string _symbol, int _tf, double _price, int _shift);
      ~SDZone();
      int Draw();
      int Erase();
};

//+----------------------------------------------------------------------------+
//| 
//+----------------------------------------------------------------------------+
class SDZoneManager {
   public:
     SDZone *levels[];
     Impulse *impulses[];
   public:
      SDZoneManager();
      ~SDZoneManager();
      int GetLevelCount();
      SDZone* GetLevel(int idx);
      int Add(SDZone* sr);
      int FindImpulses(int iBar, int period);
      int Generate(SwingGraph* Swings);
      int GetGroupProximity();  
      int CountLevelHits(double level, int bar1, int bar2, CandleRegion region=ANY_REGION, MatchType matchtype=COLLISION, CollisionVector vector=FROM_ANYWHERE);
      int Intersects(double price, int bar1, int bar2);
};






//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
Impulse::Impulse(int dir, int startbar, int endbar, int len, int obibar, datetime dt1, datetime dt2, double ht, double ndev){
   this.direction=dir;
   this.start_ibar=startbar;
   this.end_ibar=endbar;
   this.chainlen=len;
   this.ob_ibar=obibar;
   this.startdt=dt1;
   this.enddt=dt2;
   this.height=ht;
   this.n_deviations=ndev;
}


//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
int SDZoneManager::FindImpulses(int iBar, int period) {
   Impulse *moves[];
   double point=MarketInfo(Symbol(),MODE_POINT);
   
   for(int i=iBar; i<iBar+period; i++) {
      if(i==iBar) {
         ArrayResize(moves, ArraySize(moves)+1);
         moves[ArraySize(moves)-1]=new Impulse(
            Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0,
            i,i,1,-1,Time[i],Time[i],
            (Close[i]-Open[i])/point,
            0
         );
         continue;
      }
      
      int dir=Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0;
      Impulse* last = moves[ArraySize(moves)-1];
      
      // Merge properties of impulses chained together.
      // New impulse extends move by 1 bar to the left.
      // Extend startdt, start_ibar, and height
      if(last.direction == dir) {
         log("Found an impulse chain!");
         last.height+=(Close[i]-Open[i])/point;
         last.start_ibar=i;
         last.chainlen++;
         last.startdt=Time[i];
         moves[ArraySize(moves)-1] = last;
      }
      // New impulse
      else {
         Impulse* x=new Impulse(
            Close[i]>Open[i] ? 1 : Close[i]<Open[i] ? -1 : 0,
            i,i,1,-1,Time[i],Time[i],
            (Close[i]-Open[i])/point,
            0
         );
         ArrayResize(moves, ArraySize(moves)+1);
         moves[ArraySize(moves)-1]=x;
      }
   }

   double heights[];
   ArrayResize(heights,ArraySize(moves));
   for(int i=0; i<ArraySize(moves); i++) {
      heights[i] = moves[i].height;
   }
   double mean_height = Average(heights);
   double variance = Variance(heights, mean_height);
   double std = MathSqrt(variance);
      
   for(int i=0; i<ArraySize(moves); i++){
      moves[i].n_deviations = moves[i].height/std;
      if(MathAbs(moves[i].n_deviations) >= MinImpulseStdDevs) {
         moves[i].ob_ibar=moves[i].start_ibar+1;
         ArrayResize(impulses, ArraySize(impulses)+1);
         // **** WARNING: PROBABLY NOT SAFE ********
         impulses[ArraySize(impulses)-1]=moves[i];
      }     
   }
   
   log("Updated impulses from iBar "+iBar+"-"+(iBar+period)+". Impulses:"+(string)ArraySize(impulses));
   
   int max_up=0, max_down=0;
   for(int i=1; i<ArraySize(impulses); i++) {      
      if(impulses[i].height > impulses[max_up].height)
         max_up=i;
      else if(impulses[i].height < impulses[max_down].height)
         max_down=i;
   }
   
   impulses[max_up].n_deviations = impulses[max_up].height/std;
   if(MathAbs(impulses[max_up].n_deviations) >= 3)
      impulses[max_up].ob_ibar=impulses[max_up].start_ibar+1;
      
   impulses[max_down].n_deviations = impulses[max_down].height/std;
   if(MathAbs(impulses[max_down].n_deviations) >= 3)
      impulses[max_down].ob_ibar=impulses[max_down].start_ibar+1;
   
   log("Mean chain height:"+DoubleToStr(mean_height,2)+" pips, Std_Dev:"+DoubleToStr(std,2)+" pips");
   log(impulseToStr(impulses[max_up], std));
   log(impulseToStr(impulses[max_down], std));
 
}

//+---------------------------------------------------------------------------+
//| 
//+---------------------------------------------------------------------------+
string impulseToStr(Impulse* x, double std) {
   double point=MarketInfo(Symbol(),MODE_POINT);
   string dir= x.direction == 1 ? "upward" : x.direction==-1 ? "downward" : "sideways"; 
   string s = TimeToStr(x.startdt)+": "+(string)x.chainlen+"-chain "+dir+" impulse, height:"+DoubleToStr(x.height,2)+" pips, "+DoubleToStr(x.n_deviations,2)+"x STD. ";
   if(x.ob_ibar >=0)
      s+=" Parent OrderBlock: iBar["+(string)x.ob_ibar+"]";
   return s;
}










//+---------------------------------------------------------------------------+
SDZone::SDZone(string _symbol, int _tf, double _price, int _shift){
   this.symbol=_symbol;
   this.tf=_tf;
   this.price=_price;
   this.shift=_shift;
   this.n_hits=0;
   this.n_misses=0;
   this.Draw();
}

//+---------------------------------------------------------------------------+
SDZone::~SDZone(){
   this.Erase();
}

//+---------------------------------------------------------------------------+
int SDZone::Draw(){
   this.name="SR_"+DoubleToStr(this.price);
   this.lblname=this.name+"_lbl";
   CreateTrendline(
      this.name,
      iTime(NULL,0,0),this.price,iTime(NULL,0,this.shift),this.price,
      0,SR_LINE_COLOR,STYLE_SOLID,SR_LINE_WIDTH,true,false,true,0);
   return 1;
}

//+---------------------------------------------------------------------------+
int SDZone::Erase(){
   ObjectDelete(0,this.name);
   ObjectDelete(0,this.lblname);
   return 1;
}


//+---------------------------------------------------------------------------+
SDZoneManager::SDZoneManager(){
}

//+---------------------------------------------------------------------------+
SDZoneManager::~SDZoneManager(){

}

//+---------------------------------------------------------------------------+
int SDZoneManager::GetLevelCount(){
   return ArraySize(this.levels);
}

//+---------------------------------------------------------------------------+
SDZone* SDZoneManager::GetLevel(int idx){
   if(idx >= ArraySize(this.levels)){
      log("SDZoneManager::GetLevel(): Invalid index "+(string)idx);
      return NULL;
   }
   return this.levels[idx];
}

//+---------------------------------------------------------------------------+
int SDZoneManager::Add(SDZone* sr){
   ArrayResize(this.levels,ArraySize(this.levels)+1);
   this.levels[ArraySize(this.levels)-1]=sr;
   return 1;
}

//+---------------------------------------------------------------------------+
 // Number of pips to group proximate SR levels by
//+---------------------------------------------------------------------------+
int SDZoneManager::GetGroupProximity() {
   int baseGrpRad = 20;
   double grpMult = 0.01;
   int base_tf=PERIOD_M5;
   int x= baseGrpRad + (int)((PeriodSeconds()/base_tf)*grpMult);
   //log("GrpProximity (pips):"+(string)x);
   return x;
}

//+---------------------------------------------------------------------------+
//| Draws SR level trendlines/zones + hit rate stats                          |
//+---------------------------------------------------------------------------+
int SDZoneManager::Generate(SwingGraph* Swings){
   // Rmv existing levels
   for(int i=0; i<ArraySize(this.levels); i++){
      this.levels[i].Erase();
   }
   
   double nodes[][2];        // 2D-array, each element is {price,nodeIndex}
   ArrayResize(nodes,Swings.NodeCount());
   
   log("");
   log("----- Generating SR Levels -----");
   
   for(int i=0; i<Swings.NodeCount(); i++){
      SwingPoint* sp=Swings.GetNode(i);
      if(sp.MyLevel!=LONG_TERM)
         continue;
      
      nodes[i][0]=sp.GetValue();
      nodes[i][1]=i;
   }
   ArraySort(nodes,WHOLE_ARRAY,0,MODE_ASCEND); // Sort by price levels

   int n_ungrp=0;
   int n_grp=0;
   
   // Group + Draw SR level trendlines/zones
   for(int i=0; i<ArrayRange(nodes,0); i++){
      double group[];
      
      if(nodes[i][0]==0.0)
         continue;
      appendDoubleArray(group,nodes[i][1]);
      
      // Group levels with close proximity
      for(int j=i+1; j<ArrayRange(nodes,0); j++){
         if(nodes[j][0]==0)
            continue;
         if(MathAbs(ToPips(nodes[i][0])-ToPips(nodes[j][0])) < GetGroupProximity()){
            appendDoubleArray(group,nodes[j][1]);
            nodes[j][0]=0;
         }
      }
      
      // Evaluate historic hit rate of SR level
      SwingPoint* sp=(SwingPoint*)Swings.GetNode((int)group[0]);
      double p=sp.Type==LOW? sp.L: sp.H;
      int s_misses=CountLevelHits(p, sp.Shift, 1, WICK_AREA, CLOSED_BEYOND, FROM_ABOVE);
      int r_misses=CountLevelHits(p, sp.Shift, 1, WICK_AREA, CLOSED_BEYOND, FROM_BELOW);
      int s_hits=CountLevelHits(p, sp.Shift, 1, WICK_AREA, COLLISION, FROM_ABOVE);
      int r_hits=CountLevelHits(p, sp.Shift, 1, WICK_AREA, COLLISION, FROM_BELOW);
      
      // Draw ungrouped levels as trendline
      if(ArraySize(group)==1){
         SwingPoint* _sp=Swings.GetNode((int)group[0]);
         this.Add(new SDZone(Symbol(),0,_sp.GetValue(),_sp.Shift));
         /*CreateTrendline("SR_"+(string)i,iTime(NULL,0,0),
            _sp.GetValue(),iTime(NULL,0,_sp.Shift),_sp.GetValue(),0,
            SR_LINE_COLOR,STYLE_SOLID,SR_LINE_WIDTH,
            true,false,true,0);*/
         n_ungrp++;
      }
      // Draw grouped levels as rectangular zone
      else if(ArraySize(group)>1){
         double prices[];
         datetime dt[];
         for(int k=0; k<ArraySize(group); k++){
            SwingPoint* _sp=Swings.GetNode((int)group[k]);
            appendDoubleArray(prices,_sp.GetValue());
            appendDtArray(dt,_sp.DT);
         }
          this.Add(new SDZone(Symbol(),0,prices[ArrayMinimum(prices,WHOLE_ARRAY,0)],dt[ArrayMinimum(dt,WHOLE_ARRAY,0)]));
          this.Add(new SDZone(Symbol(),0,prices[ArrayMaximum(prices,WHOLE_ARRAY,0)],dt[ArrayMinimum(dt,WHOLE_ARRAY,0)]));
         /*CreateRect("SR+"+(string)group[0]+"_rect", 
            dt[ArrayMinimum(dt,WHOLE_ARRAY,0)],
            prices[ArrayMaximum(prices,WHOLE_ARRAY,0)],
            iTime(NULL,0,0),
            prices[ArrayMinimum(prices,WHOLE_ARRAY,0)],
            0,0,SR_ZONE_COLOR,STYLE_SOLID,1,true,true,true,true,0
         ); */
         n_grp++;
      }
      
      // Print SR level label
      //string lbl="H:"+(string)(s_hits+r_hits)+", M:"+(string)(s_misses+r_misses);
      //CreateText("SR_lbl_"+(string)i,lbl,
      //   0,ANCHOR_LOWER,p,0,0,0,"Arial",8,clrBlack,0.0,true,false,true,0);
   }
   log("Discovered Levels: "+(string)n_ungrp+" Ungrouped, "+(string)n_grp+" Grouped.");
   return 1;
}

//+---------------------------------------------------------------------------+
//+---------------------------------------------------------------------------+
int SDZoneManager::CountLevelHits(double level, int bar1, int bar2, CandleRegion region=ANY_REGION, MatchType matchtype=COLLISION, CollisionVector vector=FROM_ANYWHERE){
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
int SDZoneManager::Intersects(double price, int bar1, int bar2) {
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
int GetSignal(OrderManager* OM){

   // enum: OP_BUY, OP_SELL, OP_BUYLIMIT, OP_SELLLIMIT
   //Order* orders[];
   //OM.GetActiveOrders(orders);
        
   //if(order.Type==OP_SELL || order.Type==OP_SELLLIMIT)
         
   if(true){ //&& ord.HasExistingPosition(NULL, int otype)){
      return OPEN_LONG;
   }
   else if(true){
      return OPEN_SHORT;
   }
   else if(true){
      return CLOSE_LONG;
   }
   else if(true){
      return CLOSE_SHORT;
   }
   return -1;
}




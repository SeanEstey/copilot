//+----------------------------------------------------------------------------+
//|                                                          FX/SwingGraph.mqh |
//|                                                 Copyright 2018, Sean Estey |
//+----------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict

#include <FX/Chart.mqh>
#include <FX/Draw.mqh>
#include <FX/SwingPoint.mqh>
#include <FX/Impulses.mqh>

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
class NodeLink {
   public:
      SwingPoint* Left;
      SwingPoint* Right;
      string TrendlineName;      
      string TrendlineLblName;   
      string TrendlineLblVal;    
      bool TrendlineShown;       
      
      //----------------------------------------------------------------------------
      NodeLink(SwingPoint* _left, SwingPoint* _right){
         this.Left=_left;
         this.Right=_right;
         this.TrendlineName="";
         this.TrendlineLblName="";
         this.TrendlineLblVal="";
         this.TrendlineShown=false;
      
         // Create trendline between SP's and Label
         double p1= Left.Type==HIGH? Left.H: Left.L;
         double p2= Right.Type==HIGH? Right.H: Right.L;
         
         // HL,HH,LH,LL
         string desc= p2-p1<0? "L": p2-p1>0? "H": "E";
         desc+=Left.Type==HIGH?"H":"L";
         this.TrendlineName=desc+"_trendl_"+(string)Left.Shift;
         this.TrendlineLblName=this.TrendlineName+"_lbl";
         int center=Left.Shift-MathFloor((Left.Shift-Right.Shift)/2);
         double ydiff = MathAbs(p1-p2);
         this.TrendlineLblVal= desc+","+ToPipsStr(ydiff,0)+","+(string)(Left.Shift-Right.Shift);
         
         // Create Trendline + Label objects
         CreateTrendline(this.TrendlineName,Left.DT,p1,Right.DT,p2,0,clrMagenta,0,1,true,false);         
         CreateText(this.TrendlineLblName,this.TrendlineLblVal,
            center, this.Left.Type==HIGH? ANCHOR_LOWER : ANCHOR_UPPER, p1<p2 ? p1+(ydiff/2) : p2+(ydiff/2),
            0,0,"Arial",7, clrMagenta);
      }
      
      //----------------------------------------------------------------------------
      ~NodeLink(){
         ObjectDelete(this.TrendlineName);
         ObjectDelete(this.TrendlineLblName);
      }
};

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
class SwingGraph {   
   public:
      SwingPoint* Nodes[];
      NodeLink* Links[];
      Impulse* impulses[];  

      SwingGraph(){
         log("SwingGraph constructor");
      }
      ~SwingGraph(){
         for(int i=0; i<ArraySize(this.Nodes); i++){
            delete this.Nodes[i];
         }
         for(int i=0; i<ArraySize(this.Links); i++){
            delete this.Links[i];
         }
         for(int i=0; i<ArraySize(this.impulses); i++){
            delete this.impulses[i];
         }
         log("SwingGraph destructor");
      }
      
      //----------------------------------------------------------------------------
      void AddNode(SwingPoint* pt){
         ArrayResize(this.Nodes, ArraySize(this.Nodes)+1);
         this.Nodes[ArraySize(this.Nodes)-1]=pt;
      }
      //----------------------------------------------------------------------------
      void AddLink(NodeLink* n){
         ArrayResize(this.Links, ArraySize(this.Links)+1);
         this.Links[ArraySize(this.Links)-1]=n;
      }
      //----------------------------------------------------------------------------
      SwingPoint* GetNode(int shift){
         // Return matching node.
         // TODO: Make into sorted array (by shift) to speed up this method.
         for(int i=0; i<ArraySize(this.Nodes); i++) {
            if(this.Nodes[i].Shift == shift)
               return this.Nodes[i];
         }
         log("SwingPoint not found! searched "+(string)ArraySize(this.Nodes)+" nodes.");
         return NULL;
      }
      //----------------------------------------------------------------------------
      int FilterNodes(SwingPoint* &dest[], int idx1=0, int idx2=0, int min_lvl=-1, int type=-1){         
         int limit=idx2>0? idx2 : ArraySize(this.Nodes)-1;
         
         for(int i=idx1; i<limit; i++) {
            if(min_lvl>-1 && this.Nodes[i].Level<min_lvl)
               continue;
            if(type>-1 && this.Nodes[i].Type!=type)
               continue;
            ArrayResize(dest,ArraySize(dest)+1);
            dest[ArraySize(dest)-1]=this.Nodes[i];
         }
         //debuglog("Filtered node list returned. Nodes:"+(string)ArraySize(dest)+", Levels:"+(string)min_lvl+"+, Type:"+(string)type);
         return ArraySize(dest);         
      }
      //----------------------------------------------------------------------------
      // Identify if OHLC candle is valid swing point
      bool isSwingPoint(int bar, SP_Type type, SP_Define len){
         int min=len==THREE_BAR? 1: 2;
         int max=len==THREE_BAR? Bars-2: Bars-3;
         
         // Bounds check
         if(bar<min || bar>max)
            return false;
         
         double p=type==HIGH? iHigh(NULL,0,bar) : iLow(NULL,0,bar);
         int n_loops=len==THREE_BAR? 1: len==FIVE_BAR? 2: 0;
         
         // Loop 1: check nodes[i-1] to nodes[i+1]
         // Loop 2: check nodes[i-2] to nodes[i+2]
         for(int i=0; i<n_loops; i++) {
            int l_idx=bar-(i+1);
            int r_idx=bar+(i+1);
            
            if(type==HIGH && (p<iHigh(NULL,0,l_idx) || p<iHigh(NULL,0,r_idx)))
               return false;
            else if(type==LOW && (p>iLow(NULL,0,l_idx) || p>iLow(NULL,0,r_idx)))
               return false;
         }
         return true;
      }
      //----------------------------------------------------------------------------
      void Build(string symbol, ENUM_TIMEFRAMES tf, int shift1, int shift2){
         log("Building SwingGraph...");
         // Identify new STL's/STH's from raw candle data
         // Identify STH/STL. Loop left-to-right.
         for(int i=shift1; i>=shift2; i--) {      
            if(isSwingPoint(i,HIGH,THREE_BAR))
               AddNode(new SwingPoint(tf,i,HIGH,THREE_BAR,false));
            if(isSwingPoint(i,LOW,THREE_BAR))
               AddNode(new SwingPoint(tf,i,LOW,THREE_BAR,false));  
         }
         log("Built swing graph. Nodes:"+(string)ArraySize(this.Nodes)+", Graph Bars:"+(string)shift1+" - "+(string)shift2);
      }
      //----------------------------------------------------------------------------
      void UpdateNodes(){
         SwingPoint* tmp1[];
         int n_med1=this.FilterNodes(tmp1,0,0,MEDIUM);
         SwingPoint* tmp2[];
         int n_long1=this.FilterNodes(tmp2,0,0,LONG);
         
         // 1) Iterate all STL/STH nodes and update to ITL/ITH if needed
         // e.g. If a STH is is higher than its left and right neighbor, it becomes an ITH
         SwingPoint* ftr[];
         this.FilterNodes(ftr,0,0,SHORT,HIGH);
         for(int i=1; i<ArraySize(ftr)-1; i++) {
            if(ftr[i].H>ftr[i-1].H && ftr[i].H>ftr[i+1].H)
               ftr[i].UpdateLevel(MEDIUM);
         }
         ArrayResize(ftr,0);
         this.FilterNodes(ftr,0,0,SHORT,LOW);
         for(int i=1; i<ArraySize(ftr)-1; i++) {
            if(ftr[i].L<ftr[i-1].L && ftr[i].L<ftr[i+1].L)
               ftr[i].UpdateLevel(MEDIUM);
         }
         
         // 2) Same as prior loop for updating ITL/ITH-->LTL/LTH
         ArrayResize(ftr,0);
         this.FilterNodes(ftr,0,0,MEDIUM,HIGH);
         for(int i=1; i<ArraySize(ftr)-1; i++) {
            if(ftr[i].H>ftr[i-1].H && ftr[i].H>ftr[i+1].H)
               ftr[i].UpdateLevel(LONG);
         }
         ArrayResize(ftr,0);
         this.FilterNodes(ftr,0,0,MEDIUM,LOW);
         for(int i=1; i<ArraySize(ftr)-1; i++) {
            if(ftr[i].L<ftr[i-1].L && ftr[i].L<ftr[i+1].L)
               ftr[i].UpdateLevel(LONG);
         }
         
         int n_med2=this.FilterNodes(tmp1,0,0,MEDIUM);
         int n_long2=this.FilterNodes(tmp2,0,0,LONG);
         
         log("UpdateNodes() "+(string)(n_med2-n_med1)+" new Lvl_1 nodes, "+(string)(n_long2-n_long1)+" new Lvl_2 nodes.");
         
         // TODO: Move this into UpdateNodeLinks()
         for(int i=0; i<ArraySize(this.Nodes); i++){
            if(this.Nodes[i].Level<1)
               continue;
            UpdateNodeLinks(this.Nodes[i],i);
         }
         debuglog("UpdateNodeLinks() "+(string)ArraySize(this.Links)+" connections total.");
      }
      
      //-----------------------------------------------------------------------+
      void UpdateNodeLinks(SwingPoint* pt, int node_idx){
         // Connect Lvl1 Nodes-->Lvl1+ Nodes of same Type (to the right)
         // Connect Lvl2 Nodes-->Lvl2 Nodes of same Type (to the right)
         //for(int i=0; i<ArraySize(this.Links); i++){
         //   delete this.Links[i];
         //}
         SwingPoint* ftr[];
         
         if(pt.Type==HIGH){
            this.FilterNodes(ftr,node_idx+1,0,MEDIUM,HIGH);    // Get adjacent Medium/Longterm SwingLow Node
            if(ArraySize(ftr)>0){
               AddLink(new NodeLink(pt, ftr[0]));
            }
         }
         else if(pt.Type==LOW) {
            this.FilterNodes(ftr,node_idx+1,0,MEDIUM,LOW);    // Get adjacent Medium/Longterm SwingHigh Node
            if(ArraySize(ftr)>0){
               //SwingPoint* next=ftr[0];
               AddLink(new NodeLink(pt, ftr[0]));
            }
         }
      }
};

  
//+----------------------------------------------------------------------------+
//|                                                          FX/SwingPoint.mqh |
//|                                                 Copyright 2018, Sean Estey |
//+----------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property strict

#include <FX/Chart.mqh>
#include <FX/Draw.mqh>

#define LBL_SHORT_FONT           "Arial"
#define LBL_MED_FONT             "Arial"  
#define LBL_LONG_FONT            "Arial Bold"
#define LBL_SHORT_FONT_SIZE      8
#define LBL_MED_FONT_SIZE        8
#define LBL_LONG_FONT_SIZE       8
#define LBL_SHORT_FONT_COLOR     clrGray
#define LBL_MED_FONT_COLOR       clrDarkBlue
#define LBL_LONG_FONT_COLOR      clrDarkBlue
#define VERTEX_COLOR             clrMagenta
#define VERTEX_SIZE              18

//---Swing Point enums
enum SP_Define {THREE_BAR,FIVE_BAR};
enum SP_Type {LOW,HIGH};
enum SP_Level {SHORT,MEDIUM,LONG};


//-----------------------------------------------------------------------------+
/* A high/low candle surrounded by 2 lower highs/higher lows.
 * Categorized into: Short-term (ST), Intermediate-term (IT), Long-term (LT) */
//-----------------------------------------------------------------------------+
class SwingPoint {
   public:
      int TF;
      datetime DT;
      int Shift;
      double O;
      double C;
      double H;
      double L;    
      SP_Level Level;
      SP_Type Type;
      SP_Define Length;
      string EllipseName;
      string LblName;            // Graphic object
      string LblVal;             // Graphic object
      string VertexName;
      bool LblShown;             // Graphic object
      
   public:
      //-----------------------------------------------------------------------+
      void SwingPoint(int tf,int shift, SP_Type type, SP_Define len, bool showlbl=true){
         this.Level=SHORT;
         this.Type=type;
         this.Length=len;
         this.TF=tf;
         this.Shift=shift;
         this.DT=Time[shift];
         this.O=Open[shift];
         this.C=Close[shift];
         this.H=High[shift];
         this.L=Low[shift];
         
         // Init Graphics objects
         this.LblName=this.ToString()+"_lbl_"+(string)this.Shift;
         this.LblVal= showlbl? this.ToString(): "";
         this.LblShown=showlbl;
         ENUM_ANCHOR_POINT anchor=this.Type==HIGH? ANCHOR_LOWER: ANCHOR_UPPER;
         CreateText(this.LblName,this.LblVal,this.Shift,anchor,0,0,0,0,
            LBL_SHORT_FONT,LBL_SHORT_FONT_SIZE,LBL_SHORT_FONT_COLOR);     
      }
      
      //----------------------------------==-----------------------------------+
      void UpdateLevel(SP_Level lvl) {
         this.Level=lvl;
         this.LblShown=true;
         this.LblVal=this.ToString();
         
         string font= lvl==MEDIUM? LBL_MED_FONT: LBL_LONG_FONT;
         string _color= lvl==MEDIUM? LBL_MED_FONT_COLOR: LBL_LONG_FONT_COLOR;
         string size= lvl==MEDIUM? LBL_MED_FONT_SIZE: LBL_LONG_FONT_SIZE;
         ObjectSetText(this.LblName,this.LblVal,size,font,_color);
         
         this.VertexName=this.ToString()+"_vertex_"+(string)this.Shift;
         double p=this.Type==HIGH?this.H:this.L;
         if(ObjectFind(0,this.VertexName)==-1)
            CreateText(this.VertexName,"",this.Shift,-1,p,this.DT,0,LBL_SHORT_FONT,LBL_SHORT_FONT_SIZE,LBL_SHORT_FONT_COLOR,0,0,true,false,false);
         ObjectSetText(this.VertexName, CharToStr(159), VERTEX_SIZE, "Wingdings", VERTEX_COLOR);
      }
            
      //-----------------------------------------------------------------------+
      void ~SwingPoint() {
         ObjectDelete(0,this.LblName);
         ObjectDelete(0,this.VertexName);
         //debuglog("~SwingPoint()");
      }
      
      //-----------------------------------------------------------------------+
      void ShowLabel(bool toggle){
         this.LblShown=toggle? true: false;
         string val=toggle? this.ToString(): "";
         ObjectSetText(this.LblName,this.LblVal);
      }
      
      //-----------------------------------------------------------------------+
      string ToString(){
         string prefix= this.Level==SHORT? "ST": this.Level==MEDIUM? "IT": this.Level==LONG? "LT": "";
         string sufix= this.Type==LOW? "L": this.Type==HIGH? "H" : "";
         return prefix+sufix; 
      }
};
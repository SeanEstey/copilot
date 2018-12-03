//+------------------------------------------------------------------+
//|                                              FX/ChartObjects.mqh |
//|                                       Copyright 2018, Sean Estey |
//+------------------------------------------------------------------+

#property copyright "Copyright 2018, Sean Estey"
#property strict

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>

struct Rectangle {
   color clr;
   datetime dt1;
   double p1;
   datetime dt2;
   double p2;
};

//+---------------------------------------------------------------------------+
//| Create vertical line object
//+---------------------------------------------------------------------------+
void CreateVLine(int bar, string& objlist[]) {
   int id=0;
   string name = "vline_"+(string)bar;
   
   if(!ObjectCreate(id, name, OBJ_VLINE, 0, Time[bar-1], 0))
      return;   
   ObjectSetInteger(id, name, OBJPROP_COLOR, clrBlack); 
   ObjectSetInteger(id, name, OBJPROP_STYLE, STYLE_DASH); 
   ObjectSetInteger(id, name, OBJPROP_WIDTH, 1); 
   ObjectSetInteger(id, name, OBJPROP_BACK, false); 
   ObjectSetInteger(id, name, OBJPROP_SELECTABLE, false); 
   ObjectSetInteger(id, name, OBJPROP_SELECTED, false); 
   ObjectSetInteger(id, name, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, name, OBJPROP_ZORDER, 0);
   appendStrArray(objlist, name);
}

//+---------------------------------------------------------------------------+
//| Create line object between 2 given points
//+---------------------------------------------------------------------------+
void CreateLine(string name, datetime dt1, double p1, datetime dt2, double p2,
               color clr, string& objlist[]) {
   int id=0;
   
   if(!ObjectCreate(id, name, OBJ_TREND, 0, dt1, p1, dt2, p2))
      return;   
   ObjectSetInteger(id, name, OBJPROP_COLOR, clr); 
   ObjectSetInteger(id, name, OBJPROP_STYLE, STYLE_SOLID); 
   ObjectSetInteger(id, name, OBJPROP_WIDTH, 3); 
   ObjectSetInteger(id, name, OBJPROP_BACK, false); 
   ObjectSetInteger(id, name, OBJPROP_SELECTABLE, false); 
   ObjectSetInteger(id, name, OBJPROP_SELECTED, false); 
   ObjectSetInteger(id, name, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(id, name, OBJPROP_ZORDER, 0);
   ObjectSetInteger(id, name, OBJPROP_RAY_RIGHT, false);
   appendStrArray(objlist, name);
}

//+----------------------------------------------------------------------------+
//| Create ArrowUp or ArrowDown chart object.
//+----------------------------------------------------------------------------+
void CreateArrow(string name, string symbol, int obj, int shift, color clr, string& objlist[]) { 
   double price, ypos=0;
   int width=7;
   datetime time=iTime(symbol,0,shift);   // anchor point time 
   ENUM_ARROW_ANCHOR anchor=0;             
   
   if(obj == OBJ_ARROW_UP) {
      anchor=ANCHOR_TOP;
      price=iLow(symbol,0,shift);     // anchor point price 
      ypos=price*0.9999;
   }
   else if(obj == OBJ_ARROW_DOWN) {
      anchor=ANCHOR_BOTTOM;
      price=iHigh(symbol,0,shift);
      ypos=price*1.0001;
   }
   else if(obj==OBJ_ARROW_STOP || obj==OBJ_ARROW_CHECK) {
      anchor=ANCHOR_TOP;
       price=iLow(symbol,0,shift);
      ypos=price*0.9999;
   }
   
   if(!ObjectCreate(0,name,obj,0,time,ypos)) {
      log("Error creating arrow '"+name+"'. Reason:"+(string)err_msg());
      return; 
   }
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor); 
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr); 
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); 
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width); 
   ObjectSetInteger(0, name, OBJPROP_BACK, false); 
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false); 
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false); 
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false); 
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, name);
   appendStrArray(objlist, name);
} 

//+----------------------------------------------------------------------------+
//+----------------------------------------------------------------------------+
bool CreateText(string text, int bar, ENUM_ANCHOR_POINT anchor, string& objlist[],
   const long chart_ID=0,             
   const int sub_window=0,
   const string font="Arial",
   const int font_size=10,
   const color clr=clrRed,
   const double angle=0.0,
   const bool back=false,
   const bool selection=false,
   const bool hidden=true,
   const long z_order=0) { 
   
   double offset, price;
   datetime time=iTime(Symbol(),0,bar);
   string name=text+"_"+(string)bar;
   
   if(anchor==ANCHOR_UPPER) {
      offset=0.9999;
      price=iLow(Symbol(),0,bar)*offset;
   }
   else if(anchor==ANCHOR_LOWER) {
      offset=1.0001;
      price=iHigh(Symbol(),0,bar)*offset;
   }
      
   ResetLastError(); 
   if(!ObjectCreate(chart_ID,name,OBJ_TEXT,sub_window,time,price)){ 
      Print(__FUNCTION__+": Failed to create text obj! Desc:"+err_msg()); 
      return(false); 
   } 
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text); 
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font); 
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size); 
   ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,angle);
   // Anchors: ANCHOR_LOWER, ANCHOR_UPPER, ANCHOR_CENTER, etc
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor); 
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr); 
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);    
   return(true); 
} 

//+----------------------------------------------------------------------------+
//+----------------------------------------------------------------------------+
bool CreateRect(datetime dt1,double p1,datetime dt2,double p2,string& objlist[],
   const long chart_ID=0,   
   const int sub_window=0,  
   const color           clr=clrLavender,   
   const ENUM_LINE_STYLE style=STYLE_SOLID,
   const int             width=1,          
   const bool            fill=true,       
   const bool            back=true,       
   const bool            selection=true,   
   const bool            hidden=true,      
   const long            z_order=0)        
  { 
  
   ResetLastError(); 
   string name="Rect_"+(string)dt1;
      
   if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE,sub_window,dt1,p1,dt2,p2)) { 
      Print(__FUNCTION__+": failed to create a rectangle! Desc:"+err_msg());
      return(false); 
   } 
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID,name,OBJPROP_FILL,true);
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style); 
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width); 
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order); 
   return(true); 
}
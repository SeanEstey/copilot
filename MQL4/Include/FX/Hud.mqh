//+---------------------------------------------------------------------------+
//|                                                                   Hud.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property version   "1.00"
#property strict
#property strict


//--- HUD
#define HUD_RECT           "HUD_RECT"
#define HUG_IMPULSE_LBL    "HUD_IMPULSE_LBL"
#define HUD_OB_LBL         "HUD_OB_LBL"
#define HUD_LL_LBL         "HUD_LL_LBL"
#define HUD_HH_LBL         "HUD_HH_LBL"
#define HUD_TREND_LBL      "HUD_TREND_LBL"
#define HUD_HOVER_BAR_LBL  "HUD_HOVER_BAR_LBL"
#define HUD_FIRST_BAR_LBL  "HUD_FIRST_BAR_LBL"

#define HUD_ITEM_START_X   35
#define HUD_ITEM_START_Y   35
#define HUD_ITEM_LBL_WIDTH 250

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/Swings.mqh>
#include <FX/Draw.mqh>


class HudItem {
   public:
      string DescName;
      string Desc;
      string ValName;
      string Val;
      int x;
      int y;
      
   HudItem(string name, string desc, string value, int xpos, int ypos){
      this.DescName=name+"_desc";
      this.Desc=desc;
      this.ValName=name+"_val";
      this.Val=value;
      this.x=xpos;
      this.y=ypos;
      
      CreateLabel(this.Desc+":",this.DescName,this.x,this.y);
      CreateLabel(this.Val,this.ValName,this.x+HUD_ITEM_LBL_WIDTH,this.y);
   }
   
   ~HudItem(){
      ObjectDelete(0,this.DescName);
      ObjectDelete(0,this.ValName);
      log("HudItem destructor");
   }
};

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
class HUD {
   public:
      HudItem* Items[];
      int x, y;
      int height, width;
      int LLBar, HHBar;          // Most significant visible High/Low bar shifts
      
      //-----------------------------------------------------------------------+
      void HUD() {
         CreateLabelRect(0,HUD_RECT,0,25,25,1000,200,C'206,225,255',2,0,C'59,114,204',0,2,false);
         log("HUD constructor");
      }
      
      //-----------------------------------------------------------------------+
      void ~HUD(){
         for(int i=0; i<ArraySize(Items); i++) {
            delete Items[i];
         }
         ObjectDelete(0,HUD_RECT);
         log("HUD destructor");
      }
      
      //-----------------------------------------------------------------------+
      void AddItem(string name, string desc, string value){
         int xpos = HUD_ITEM_START_X;
         int ypos = HUD_ITEM_START_Y * (ArraySize(Items)+1);
         ArrayResize(Items,ArraySize(Items)+1);
         Items[ArraySize(Items)-1]=new HudItem(name,desc,value,xpos,ypos);
      }
      
      //-----------------------------------------------------------------------+
      int SetItemValue(string name, string value) {
         for(int i=0; i<ArraySize(Items); i++){
            if(name+"_desc" == Items[i].DescName) {
               ObjectSetString(0,Items[i].ValName,OBJPROP_TEXT,value);
               return 1;
            }
         }
         log("Hud.SetItemValue() error. Item '"+name+"' not found.");
         return -1;         
      }
      
      //-----------------------------------------------------------------------+
      void Update() {
         // Find pivot between highest visible low/high
      }
      
      //-----------------------------------------------------------------------+
      void Redraw() {
         int first = WindowFirstVisibleBar();
         int last = first-WindowBarsPerChart();
         
         int hh_shift=iHighest(Symbol(),0,MODE_HIGH,first-last,last);
         double hh=iHigh(Symbol(),0,hh_shift);
         datetime hh_time=iTime(Symbol(),0,hh_shift);
         
         int ll_shift=iLowest(Symbol(),0,MODE_LOW,first-last,last);
         double ll=iLow(Symbol(),0,ll_shift);
         datetime ll_time=iTime(Symbol(),0,ll_shift);
         
         ObjectSetString(0,HUD_FIRST_BAR_LBL,OBJPROP_TEXT,
            "Bars: "+(string)(last+2)+"-"+(string)(first+2));
         ObjectSetString(0,HUD_LL_LBL,OBJPROP_TEXT,
            "Low: "+(string)ll+" [Bar "+(string)(ll_shift+2)+"]"); 
         ObjectSetString(0,HUD_HH_LBL,OBJPROP_TEXT,
            "High: "+(string)hh+" [Bar "+(string)(hh_shift+2)+"]"); 
         
         // Bullish/Bearish trend display
         //int trend=GetTrend();
         //string trend_text = trend==1 ? "Trend: Bullish" : trend==-1 ? "Trend: Bearish" : "Trend: None";
         //ObjectSetString(0,HUD_TREND_LBL,OBJPROP_TEXT, trend_text);
         
         log("HUD redrawn.");
      }
      
      //-----------------------------------------------------------------------+
      string ToString(){ return ""; }
};
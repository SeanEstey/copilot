//+---------------------------------------------------------------------------+
//|                                                                   Hud.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property version   "1.00"
#property strict
#property strict

//--- HUD
#define HUD_RECT_XPOS      25
#define HUD_RECT_YPOS      25
#define HUD_RECT_WIDTH     1000
#define HUD_RECT_HEIGHT    250
#define HUD_RECT_COLOR     C'206,225,255'
#define HUD_ITEM_START_X   35
#define HUD_ITEM_START_Y   35
#define HUD_ITEM_LBL_WIDTH 200

//--- Custom includes
#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/Draw.mqh>

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
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
      debuglog("HudItem destructor");
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
      
      //-----------------------------------------------------------------------+
      void HUD() {
         this.x=HUD_RECT_XPOS;
         this.y=HUD_RECT_YPOS;
         this.width=HUD_RECT_WIDTH;
         this.height=HUD_RECT_HEIGHT;
         
         CreateLabelRect(0,"hud_rect",0,
            HUD_RECT_XPOS,HUD_RECT_YPOS,HUD_RECT_WIDTH,HUD_RECT_HEIGHT,HUD_RECT_COLOR,
            2,0,C'59,114,204',0,2,false);
         debuglog("HUD constructor");
      }
      
      //-----------------------------------------------------------------------+
      void ~HUD(){
         for(int i=0; i<ArraySize(Items); i++) {
            delete Items[i];
         }
         ObjectDelete(0,"hud_rect");
         debuglog("HUD destructor");
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
      string ToString(){ return ""; }
};
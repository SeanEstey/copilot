//+---------------------------------------------------------------------------+
//|                                                                   Hud.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property version   "1.00"
#property strict

//--- HUD
#define HUD_RECT_X               25
#define HUD_RECT_Y               25
#define HUD_RECT_WIDTH           1000
#define HUD_RECT_HEIGHT          275
#define HUD_RECT_COLOR           C'59,103,186'        //C'239,255,232'
#define HUD_RECT_BORDER_COLOR    C'191,225,255'         //C'100,186,61'
#define HUD_ITEM_START_X         50
#define HUD_ITEM_START_Y         50
#define HUD_ITEM_ROW_HEIGHT      35
#define HUD_ITEM_ROW_SPACING     5
#define HUD_ITEM_LBL_WIDTH       200
#define HUD_ITEM_COL_WIDTH       500


//--- Custom includes
#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/Draw.mqh>

// Globals
int cur_row=1;
int cur_col=1;

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
      
      CreateLabel(this.Desc+":",this.DescName,this.x,this.y,0,0,0,0,"Arial",12,clrWhite);
      CreateLabel(this.Val,this.ValName,this.x+HUD_ITEM_LBL_WIDTH,this.y,0,0,0,0,"Arial",12,clrWhite);
   }
   
   ~HudItem(){
      ObjectDelete(0,this.DescName);
      ObjectDelete(0,this.ValName);
      //debuglog("HudItem destructor");
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
      int max_rows;
      string title;
      
      //-----------------------------------------------------------------------+
      void HUD(string _title) {
         this.title=_title;
         this.x=HUD_RECT_X;
         this.y=HUD_RECT_Y;
         this.width=HUD_RECT_WIDTH;
         this.height=HUD_RECT_HEIGHT;
         this.max_rows=(HUD_RECT_HEIGHT-HUD_ITEM_START_Y)/(HUD_ITEM_ROW_HEIGHT+HUD_ITEM_ROW_SPACING);
         
         CreateLabelRect("hud_rect", HUD_RECT_X,HUD_RECT_Y,HUD_RECT_WIDTH,HUD_RECT_HEIGHT,HUD_RECT_COLOR,0,0,0,0,HUD_RECT_BORDER_COLOR,0,2,false);         
         CreateLabel(this.title,"hud_title",HUD_ITEM_START_X,HUD_RECT_Y+15,0,0,0,0,"Arial Bold",12,clrWhite);
         
         debuglog("HUD() MaxRows:"+(string)this.max_rows);
      }
      
      //-----------------------------------------------------------------------+
      void ~HUD(){
         for(int i=0; i<ArraySize(Items); i++) {
            delete Items[i];
         }
         ObjectDelete(0,"hud_rect");
         ObjectDelete(0,"hud_title");
         //debuglog("HUD destructor");
      }
      
      //-----------------------------------------------------------------------+
      void AddItem(string name, string desc, string value){
         int ypos=HUD_ITEM_START_Y + (cur_row*(HUD_ITEM_ROW_HEIGHT+HUD_ITEM_ROW_SPACING));
         int xpos=HUD_ITEM_START_X+((cur_col-1)*HUD_ITEM_COL_WIDTH);
         ArrayResize(Items,ArraySize(Items)+1);
         Items[ArraySize(Items)-1]=new HudItem(name,desc,value,xpos,ypos);
         debuglog("HUD.AddItem() MaxRows:"+(string)max_rows+", Col:"+(string)cur_col+", Row:"+(string)cur_row);
          
         cur_row++;
         if(cur_row>max_rows) {
            cur_row=1;
            cur_col++;
         }
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
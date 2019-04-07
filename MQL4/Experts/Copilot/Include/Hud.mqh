//+---------------------------------------------------------------------------+
//|                                                                   Hud.mq4 |
//|                                                Copyright 2018, Sean Estey |      
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2018, Sean Estey"
#property version   "1.00"
#property strict

struct Container{
   int X,Y;
   int Width,Height;
   int PadTop, PadBottom, PadLeft, PadRight;
   color FillColor;
   color FontColor;
   color BorderColor;
   Container() {
      X=25; Y=25; Width=1250; Height=275; 
      PadTop=40; PadBottom=40; PadLeft=15; PadRight=15;
      FillColor=C'59,103,186'; FontColor=clrWhite; BorderColor=clrBlack;//C'191,225,255';
   }
};


//--- HUD
#define HUD_RECT_X               25
#define HUD_RECT_Y               25
#define HUD_RECT_WIDTH           1250
#define HUD_RECT_HEIGHT          275
#define HUD_RECT_COLOR           C'59,103,186'        //C'239,255,232'
#define HUD_RECT_BORDER_COLOR    C'191,225,255'         //C'100,186,61'
#define HUD_ITEM_START_X         50
#define HUD_ITEM_START_Y         50
#define HUD_ITEM_ROW_HEIGHT      35
#define HUD_ITEM_ROW_SPACING     5
#define HUD_ITEM_LBL_WIDTH       200
#define HUD_ITEM_COL_WIDTH       500
#define HUD_ITEM_FONT_SIZE       9

#include "Logging.mqh"
#include "Utility.mqh"
#include "Draw.mqh"


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
   public:
      HudItem(string name, string desc, string value, int xpos, int ypos){
         this.DescName=name+"_desc";
         this.Desc=desc;
         this.ValName=name+"_val";
         this.Val=value;
         this.x=xpos;
         this.y=ypos;    
         CreateLabel(this.Desc+":",this.DescName,this.x,this.y,0,0,0,0,"Arial",HUD_ITEM_FONT_SIZE,clrWhite);
         CreateLabel(this.Val,this.ValName,this.x+HUD_ITEM_LBL_WIDTH,this.y,0,0,0,0,"Arial",HUD_ITEM_FONT_SIZE,clrWhite);
      }
      ~HudItem(){
         ObjectDelete(0,this.DescName);
         ObjectDelete(0,this.ValName);
      }
};

//-----------------------------------------------------------------------------+
//|
//-----------------------------------------------------------------------------+
class HUD {
   public:
      Container Box, Status;
      HudItem* Items[];
      int MaxRows;
      string title;
   public:
      //-----------------------------------------------------------------------+
      void HUD(string _title) {
         this.title=_title;
         this.MaxRows=(Box.Height-Box.PadTop-Box.PadBottom)/(HUD_ITEM_ROW_HEIGHT+HUD_ITEM_ROW_SPACING);         
         Status.Y=Box.Y+Box.Height-Box.PadBottom;
         Status.Height=75;
         Status.FillColor=C'95,204,113';
         Status.BorderColor=clrBlack;
    
         CreateLabelRect("HudBox",Box.X,Box.Y,Box.Width,Box.Height,
            Box.FillColor,0,0,0,0,Box.BorderColor,0,2,false);
         CreateLabel(this.title,"HudTitle",
            Box.X+Box.PadLeft,Box.Y+Box.PadTop/3,0,0,0,0,"Arial Bold",12,clrWhite);     
         CreateLabelRect("HudDialogBox",Status.X,Status.Y,Status.Width,Status.Height,
            C'59,103,186',0,0,0,0,Status.BorderColor,0,1,false);         
         CreateLabel("SwingGraph built. 230 Nodes, 112 Edges","HudDialogLbl",
            Status.X+15,Status.Y+15,0,0,0,0,"Arial",10,clrWhite);
            
         // Init MT4-GUI + Controls
         int yspacing=HUD_ITEM_ROW_HEIGHT+HUD_ITEM_ROW_SPACING;
         
         AddItem("acct_name","Account","");
         AddItem("balance","Balance","");
         AddItem("free_margin", "Available Margin","");
         AddItem("unreal_pnl","Unrealized Profit","");
         AddItem("real_pnl","Realized Profit","");
         AddItem("ntrades","Active Trades","");
         AddItem("hud_hover_bar","Hover Bar","");
         //AddItem("hud_window_bars","Bars","");
         //AddItem("hud_highest_high","Highest High","");
         //AddItem("hud_lowest_low", "Lowest Low", "");
         //AddItem("hud_trend", "Swing Trend", "");
         //AddItem("hud_nodes", "Swing Nodes", "");
         //AddItem("hud_node_links", "Node Links", "");
         SetItemValue("acct_name",AccountInfoString(ACCOUNT_NAME));
         SetItemValue("balance",DoubleToStr(AccountInfoDouble(ACCOUNT_BALANCE),2));
         SetItemValue("free_margin",DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2));
         SetDialogMsg("Hud created.");
      }
      //-----------------------------------------------------------------------+
      void ~HUD(){
         for(int i=0; i<ArraySize(Items); i++)
            delete Items[i];
         ObjectDelete(0,"HudBox");
         ObjectDelete(0,"HudTitle");
         ObjectDelete(0,"HudDialogBox");
         ObjectDelete(0,"HudDialogLbl");
    
      }
      //-----------------------------------------------------------------------+
      void AddItem(string name, string desc, string value){
         double col=MathCeil(((double)ArraySize(this.Items)+1)/(double)this.MaxRows);
         double row=1+((ArraySize(this.Items))%this.MaxRows);
         int ypos=HUD_ITEM_START_Y + (int)(row*(HUD_ITEM_ROW_HEIGHT+HUD_ITEM_ROW_SPACING));
         int xpos=HUD_ITEM_START_X+(int)((col-1)*HUD_ITEM_COL_WIDTH);
         ArrayResize(Items,ArraySize(Items)+1);
         Items[ArraySize(Items)-1]=new HudItem(name,desc,value,xpos,ypos);
         //debuglog("HUD.AddItem() MaxRows:"+(string)max_rows+", Col:"+(string)col+", Row:"+(string)row);   
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
      void SetDialogMsg(string str, bool log=false){
         ObjectSetText("HudDialogLbl",str);
         if(log==true)
            log(str);
      }
};
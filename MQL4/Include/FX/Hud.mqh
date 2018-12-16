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
      X=25; Y=25; Width=1000; Height=275; 
      PadTop=40; PadBottom=40; PadLeft=15; PadRight=15;
      FillColor=C'59,103,186'; FontColor=clrWhite; BorderColor=clrBlack;//C'191,225,255';
   }
};


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
#define HUD_ITEM_FONT_SIZE       9


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
         int ypos=HUD_ITEM_START_Y + (row*(HUD_ITEM_ROW_HEIGHT+HUD_ITEM_ROW_SPACING));
         int xpos=HUD_ITEM_START_X+((col-1)*HUD_ITEM_COL_WIDTH);
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
      void SetDialogMsg(string str){
         ObjectSetText("HudDialogLbl",str);
      }
      
      //-----------------------------------------------------------------------+
      string DisplayInfoOnChart(bool on_chart = true, string sep = "\n") {
         string output;
         datetime time_current=TimeCurrent();
         string ea_name="IcedTea";
         string version="0.01";
         string ea_text = StringFormat("%s v%s", ea_name, version);
         string company=AccountInfoString(ACCOUNT_COMPANY); 
         string name=AccountInfoString(ACCOUNT_NAME); 
         long login=AccountInfoInteger(ACCOUNT_LOGIN); 
         string server=AccountInfoString(ACCOUNT_SERVER); 
         string currency=AccountInfoString(ACCOUNT_CURRENCY); 
         ENUM_ACCOUNT_TRADE_MODE account_type=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE); 
         string trade_mode; 
         switch(account_type){ 
            case  ACCOUNT_TRADE_MODE_DEMO: 
               trade_mode="demo"; 
               break; 
            case  ACCOUNT_TRADE_MODE_CONTEST: 
               trade_mode="contest"; 
               break; 
            default: 
               trade_mode="real"; 
               break; 
         } 
         ENUM_ACCOUNT_STOPOUT_MODE stop_out_mode=(ENUM_ACCOUNT_STOPOUT_MODE)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE); 
         double margin_call=AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL); 
         double stop_out=AccountInfoDouble(ACCOUNT_MARGIN_SO_SO); 
         
         output+=StringFormat("The account of the client '%s' #%d %s opened in '%s' on the server '%s'", 
                  name,login,trade_mode,company,server); 
         output+=StringFormat("Account currency - %s, MarginCall and StopOut levels are set in %s", 
                  currency,(stop_out_mode==ACCOUNT_STOPOUT_MODE_PERCENT)?"percentage":" money"); 
         output+=StringFormat("MarginCall=%G, StopOut=%G",margin_call,stop_out);
         
         string indent = ""; 
         indent = "                      ";
         output += indent + "------------------------------------------------" + sep
            + indent + StringFormat("| ACCOUNT INFORMATION:%s", sep)
            + indent + StringFormat("| Server Name: %s, Time: %s%s", AccountInfoString(ACCOUNT_SERVER), TimeToStr(time_current, TIME_DATE|TIME_MINUTES|TIME_SECONDS), sep)
            + indent + StringFormat("| Stop Out Level: %s, Leverage: 1:%d %s", stop_out, AccountLeverage(), sep)         
            + indent + "| Last error: " +  "" + sep
            + indent + "| Last message: " +  "" + sep
            + indent + "| ------------------------------------------------" + sep
            + indent + "| MARKET INFORMATION:" + sep
            + indent + "| Trend: " + "Bullish" + "" + sep
            + indent + "| ------------------------------------------------" + sep
            + indent + "| STATISTICS:" + sep
            + indent + "------------------------------------------------" + sep;
         //log(output);
         return output;
      }
      
      //-----------------------------------------------------------------------+
      string ToString(){ return ""; }
};
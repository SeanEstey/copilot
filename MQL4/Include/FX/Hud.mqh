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
         double col=MathCeil(((double)ArraySize(this.Items)+1)/(double)this.max_rows);
         double row=1+((ArraySize(this.Items))%this.max_rows);
         int ypos=HUD_ITEM_START_Y + (row*(HUD_ITEM_ROW_HEIGHT+HUD_ITEM_ROW_SPACING));
         int xpos=HUD_ITEM_START_X+((col-1)*HUD_ITEM_COL_WIDTH);
         ArrayResize(Items,ArraySize(Items)+1);
         Items[ArraySize(Items)-1]=new HudItem(name,desc,value,xpos,ypos);
         debuglog("HUD.AddItem() MaxRows:"+(string)max_rows+", Col:"+(string)col+", Row:"+(string)row);   
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
   
      if(on_chart){
         /* FIXME: Text objects can't contain multi-line text so we need to create a separate object for each line instead.
         ObjectCreate(ea_name, OBJ_LABEL, 0, 0, 0, 0); // Create text object with given name.
         // Set pixel co-ordinates from top left corner (use OBJPROP_CORNER to set a different corner).
         ObjectSet(ea_name, OBJPROP_XDISTANCE, 0);
         ObjectSet(ea_name, OBJPROP_YDISTANCE, 10);
         ObjectSetText(ea_name, output, 10, "Arial", Red); // Set text, font, and colour for object.
         // ObjectDelete(ea_name);
         */
         //Comment(output);
         ChartRedraw(); // Redraws the current chart forcedly.
      }
      
      log(output);
      return output;
   }
      
      //-----------------------------------------------------------------------+
      string ToString(){ return ""; }
};
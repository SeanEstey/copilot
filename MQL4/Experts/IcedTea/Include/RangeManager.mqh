//+----------------------------------------------------------------------------+
//|                                                           RangeManager.mqh |
//+----------------------------------------------------------------------------+
#property strict
#include "Logging.mqh"
#include "Utility.mqh"
#include "Draw.mqh"
#include "Hud.mqh"


// Globals
enum Zones {NONE, BUY_ZONE, SELL_ZONE, TP_ZONE, STOP_ZONE};

// Structs
string glbIndicatorTemporaryId;
struct ClickHistory {
   int x;
   int y;
   datetime atTime;
   double atPrice;
   datetime clickTimestamp;
};

struct Line {
   int lshift, rshift;
   double p1, p2;
}


// Class Declarations

//---------------------------------------------------------------------------------+
//|********************************* Range ****************************************|
//---------------------------------------------------------------------------------+
class RangeMatrix {
   private:
      string pair;
      ENUM_TIMEFRAMES period;
      Line origin;                                 // Set of origin points used to generate matrix
      double *primFibs[];                          // Primary fib range levels
      double *secFibs[];                           // Secondary fib range levels (within each primary range)
      int shift_start;                             // Bar offset when range originated.
      double low, mid, high;                       // Levels
      int id;                                      // Timestamp unique ref
      Zone activeZone;                             // Range section price is currentlhy occupying
      Zone lastTickZone;                           // Range section price occupied previous tick
      int line_ids[];                              // Handles to drawn line objects
      int order_id;                                // If currently in a trade
   public:
      RangeMatrix(string symbol, const ENUM_TIMEFRAMES period, int shift);
      ~RangeMatrix();
      bool IsActive();
      bool HasOpenPosition();
      bool NewZoneActive();                        // Current tick has moved price into new zone (buy/sell/tp,stop)
      string ToString();
};

//---------------------------------------------------------------------------------+
//|********************************* RangeManager *********************************|
//---------------------------------------------------------------------------------+
class RangeManager {
   protected:
      Range *ranges[];
      Range* currentRange;
      int buildModeClickCount;
      ClickHistory clicks[2];
      bool inBuildMode;
      bool mouseMoveEnabled=true;
      int drawLineMode;
      Hud* hud;
   public:
      RangeManager(Hud* hud);
      ~RangeManager(void);
      void ToggleBuildMode(bool enabled);
      bool InBuildMode() {return this.inBuildMode;}
      void UpdateBuildMode();
      void AddRange(Range *r);
      void RmvRange(Range* r);
      void ClearRanges();
      void Update();                                    // Update all ranges each tick
      Range* FindRange(double price);
      Range* GetRange(int idx);
      int RangeCount() {return ArraySize(this.ranges);}
      string ToString();
};

// Class Definitions

//----------------------------------------------------------------------------
RangeMatrix::RangeMatrix(string symbol, const ENUM_TIMEFRAMES period, int shift){
   this.pair=symbol;
   this.shift=shift;
   this.id=(string)(long)iTime(NULL,0,this.shift);
   
   for(int i=0; i<3; i++){
      //CreateHLine("range_"+this.id+"_hline_"+(string)(i+1),
      +_"+(+this.id, ranges[i].rangeLow, 0, 0, (i == 0) ? clrTurquoise : clrBlue, STYLE_SOLID, (i == 0) ? 2 : 1);
      //CreateHLine("Range" + (i+1) + "_High", ranges[i].rangeHigh, 0, 0, (i == 0) ? clrTurquoise : clrBlue, STYLE_SOLID, (i == 0) ? 2 : 1);
      //CreateHLine("Range" + (i+1) + "_Mid", ranges[i].rangeMid, 0, 0, clrGray, STYLE_DASH);      
      //ObjectSet("Range" + (i+1) + "_Low", OBJPROP_SELECTABLE, false);
      //ObjectSet("Range" + (i+1) + "_High", OBJPROP_SELECTABLE, false);
      //ObjectSet("Range" + (i+1) + "_Mid", OBJPROP_SELECTABLE, false);
   }
}

//----------------------------------------------------------------------------
RangeMatrix::~RangeMatrix(){
   for(int i=0; i<ArraySize(this.line_ids); i++) {
      ObjectDelete(this.line_ids[i]);
   }
}

//----------------------------------------------------------------------------
bool Range::IsActive(){
   return true; // WRITEME
}

//----------------------------------------------------------------------------
bool Range::HasOpenPosition(){
   return true; // WRITEME
}

//----------------------------------------------------------------------------
bool Range::NewZoneActive(){
}

//----------------------------------------------------------------------------
string Range::ToString(){
   return "WRITE_ME";
}

//----------------------------------------------------------------------------
RangeManager::RangeManager(Hud* hud){
   this.hud=hud;
   this.inBuildMode=false;
   //this.drawLineMode=0;
   this.buildModeClickCount=0;

   double baseRangeLow = GlobalVariableGet("BaseRangeLow_" + Symbol());
   double baseRangeHigh = GlobalVariableGet("BaseRangeHigh_" + Symbol());

   if(baseRangeLow != 0 && baseRangeHigh != 0) {
      Range_BuildRanges(baseRangeLow, baseRangeHigh);
   }

    Hud.AddItem("num_ranges", "# of ranges", "");
    Hud.AddItem("current_range", "Current range", "N/A");
    Hud.AddItem("draw_range_line", "Draw range", "R");
   
    return(INIT_SUCCEEDED);
}

//----------------------------------------------------------------------------
RangeManager::~RangeManager(){
   for(int i=0; i<ArraySize(this.ranges); i++){
      // WRITE_ME: check for any open trades. send warning to user
      // that all positions will be closed out.
      
      // WRITE_ME: close out any positions.
      
      // WRITE_ME: save any necessary persistent globals
      
      delete this.ranges[i];
   }
}

//----------------------------------------------------------------------------
void RangeManager::ToggleBuildMode(bool enabled){
   if(enabled){
      //Range_isDrawing = !Range_isDrawing;
      //Range_drawLineMode = 0;
      this.hud.SetItemValue("draw_range_line", "(Drawing, left-click to place range)");
   }
   else {
      // WRITE_ME
   }
}

//----------------------------------------------------------------------------
void RangeManager::UpdateBuildMode(){
   //Range_mouseMoveEnabled = true;
   CreateHLine("Line1", 0.0, 0, 0, clrTurquoise);
}

//----------------------------------------------------------------------------
void RangeManager:AddRange(Range* r){
   // WRITEME
}

//----------------------------------------------------------------------------
void RangeMaanger::RmvRange(Range* r){
   // WRITEME
}

//----------------------------------------------------------------------------
void RangeManager::HandleInput(double baseRangeLow, double baseRangeHigh){
   } else if (id == CHARTEVENT_CLICK) {
        // Get the x-y coords of the click and convert them to time-price coords
        int subwindow, x=(int)lparam, y=(int)dparam;
        datetime atTime;
        double atPrice;
        ChartXYToTimePrice(0,x,y,subwindow,atTime,atPrice);
    
        if (subwindow != 0) {
            Range_DeInit();
        } else {
    
            clicks[Range_drawLineMode].clickTimestamp=TimeGMT();
            clicks[Range_drawLineMode].x = x;
            clicks[Range_drawLineMode].y = y;
            clicks[Range_drawLineMode].atTime=atTime;
            clicks[Range_drawLineMode].atPrice=atPrice;
            
            if (Range_inBuildMode) {
                Range_drawLineMode++;
                if (Range_drawLineMode == 1) {
                    
                    CreateHLine("Line2", 0, 0, 0, clrTurquoise);
                } else if (Range_drawLineMode == 2) {
                    Range_drawLineMode = 0;
                    Range_inBuildMode = false;
                    hud.SetItemValue("draw_range", "R");
                    ObjectDelete(0, "Line1");
                    ObjectDelete(0, "Line2");
                }
            }
        }
    }
}



//----------------------------------------------------------------------------
Range* RangeManager::FindRange(string symbol, ENUM_TIMEFRAMES period, double price){
   
   // WRITEME: add checks for symbol/period
   
   for (int i = 0; i < ArraySize(ranges); i++) {
      if(price >= ranges[i].rangeLow && price <= ranges[i].rangeHigh) {
         return ranges[i];
      }
   }    
   
   // WRITEME: log Not Found warning.
   
   return NULL;
}

//----------------------------------------------------------------------------
Range* RangeManager::GetRange(int id){
   for (int i=0; i<ArraySize(this.ranges); i++){
      if(this.ranges[i].id==id)
         return this.ranges[i];
   }
   return NULL;
}

//----------------------------------------------------------------------------
void RangeManager::Update() {
   // WRITEME: iterate through ranges, manage any required trades
}
//+------------------------------------------------------------------+
//|                                                    RangeDraw.mqh |
//|                                            Copyright 2019, t04st |
//|                                                        t04st.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, t04st"
#property link      "t04st.com"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+#property strict
#property indicator_chart_window

#include "Logging.mqh"
#include "Utility.mqh"
#include "Draw.mqh"
#include "Hud.mqh"

sinput int RangeMatrix_resolution = 10;
#define KEY_R           82

string glbIndicatorTemporaryId;
struct ClickHistory {
   int x;
   int y;
   datetime atTime;
   double atPrice;
   datetime clickTimestamp;
};

int glbClickCount;
ClickHistory glbClicks[2];
bool Range_isDrawing = false;
bool Range_mouseMoveEnabled = true;
int Range_drawLineMode = 0;

class Range {
public:
    double rangeLow;
    double rangeMid;
    double rangeHigh;
};

Range* ranges[];
Range* currentRange = NULL;
    
Range* Range_FindRange(double price)
{
    for (int i = 0; i < ArraySize(ranges); i++) {
        if (price >= ranges[i].rangeLow && price <= ranges[i].rangeHigh) {
            return ranges[i];
        }
    }
    
    return NULL;
}
    
void Range_DestroyRanges()
{
    for (int i = 0; i < ArraySize(ranges); i++) {
        ObjectDelete("Range" + (i+1) + "_Low");
        ObjectDelete("Range" + (i+1) + "_High");
        ObjectDelete("Range" + (i+1) + "_Mid");

        delete ranges[i];
    }

    ArrayResize(ranges, 0);
}

void Range_BuildRanges(double baseRangeLow, double baseRangeHigh)
{
    if (ArraySize(ranges) != 0) {
        // @TODO make more efficient. just move objects and set variables rather than deleting and recreating.
        Range_DestroyRanges();
    }

    ArrayResize(ranges, 1);
 
    Range* mainRange = new Range;
    mainRange.rangeLow = baseRangeLow;
    mainRange.rangeHigh = baseRangeHigh;
    mainRange.rangeMid = (baseRangeLow + baseRangeHigh) / 2;
    ranges[0] = mainRange;
 
    GlobalVariableSet("BaseRangeLow_" + Symbol(), baseRangeLow);
    GlobalVariableSet("BaseRangeHigh_" + Symbol(), baseRangeHigh);
 
    const double rangeDiff = baseRangeHigh - baseRangeLow;
 
    for (int i = 0; i < RangeMatrix_resolution/2; i++) {
        Range* r = new Range;
        r.rangeHigh = baseRangeLow - (rangeDiff*i);
        r.rangeLow = r.rangeHigh - rangeDiff;
        r.rangeMid = (r.rangeHigh + r.rangeLow) / 2;

        ArrayResize(ranges, ArraySize(ranges)+1);
        ranges[ArraySize(ranges)-1] = r;
    }

    int offset = RangeMatrix_resolution/2;

    for (int i = 0; i < RangeMatrix_resolution/2; i++) {
        Range *r = new Range;
        r.rangeLow = baseRangeHigh + (rangeDiff*i);
        r.rangeHigh = r.rangeLow + rangeDiff;
        r.rangeMid = (r.rangeHigh + r.rangeLow) / 2;

        ArrayResize(ranges, ArraySize(ranges)+1);
        ranges[ArraySize(ranges)-1] = r;
    }

    for (int i = 0; i < ArraySize(ranges); i++) {
        CreateHLine("Range" + (i+1) + "_Low", ranges[i].rangeLow, 0, 0, (i == 0) ? clrTurquoise : clrBlue, STYLE_SOLID, (i == 0) ? 2 : 1);
        CreateHLine("Range" + (i+1) + "_High", ranges[i].rangeHigh, 0, 0, (i == 0) ? clrTurquoise : clrBlue, STYLE_SOLID, (i == 0) ? 2 : 1);
        CreateHLine("Range" + (i+1) + "_Mid", ranges[i].rangeMid, 0, 0, clrGray, STYLE_DASH);
        
        ObjectSet("Range" + (i+1) + "_Low", OBJPROP_SELECTABLE, false);
        ObjectSet("Range" + (i+1) + "_High", OBJPROP_SELECTABLE, false);
        ObjectSet("Range" + (i+1) + "_Mid", OBJPROP_SELECTABLE, false);
    }
}

int Range_Init(HUD* hud)
{
    glbClickCount=0;

    double baseRangeLow = GlobalVariableGet("BaseRangeLow_" + Symbol());
    double baseRangeHigh = GlobalVariableGet("BaseRangeHigh_" + Symbol());

    if (baseRangeLow != 0 && baseRangeHigh != 0) {
        Range_BuildRanges(baseRangeLow, baseRangeHigh);
    }

    Hud.AddItem("num_ranges", "# of ranges", "");
    Hud.AddItem("current_range", "Current range", "N/A");
    Hud.AddItem("draw_range_line", "Draw range", "R");
   
    return(INIT_SUCCEEDED);
}

void Range_DeInit()
{
    ObjectDelete(0, "Line1");
    ObjectDelete(0, "Line2");
    
    Range_DestroyRanges();
}

void Range_Update(HUD* hud) {
    currentRange = Range_FindRange(Close[0]);

    Hud.SetItemValue("num_ranges", (string)ArraySize(ranges));
    Hud.SetItemValue("draw_range_line", (string)(Range_drawLineMode));
    Hud.SetItemValue("current_range", (currentRange == NULL) ? "N/A" : ("Low: " + currentRange.rangeLow + " | Mid: " + currentRange.rangeMid + " | High: " + currentRange.rangeHigh));
}

void Range_HandleChartEvent(HUD* hud, const int id,const long &lparam,const double &dparam,const string &sparam)
{
    if (id == CHARTEVENT_KEYDOWN) {
    // Cancel the drawing if Esc is pressed
        if (lparam == 27) {
            glbClickCount = 0;
            Range_DeInit();
        } else {
            
            Range_HandleKeyPress(hud, lparam, dparam, sparam);
        }
    } else if (id == CHARTEVENT_CLICK) {
        // Get the x-y coords of the click and convert them to time-price coords
        int subwindow, x=(int)lparam, y=(int)dparam;
        datetime atTime;
        double atPrice;
        ChartXYToTimePrice(0,x,y,subwindow,atTime,atPrice);
    
        if (subwindow != 0) {
            Range_DeInit();
        } else {
    
            glbClicks[Range_drawLineMode].clickTimestamp=TimeGMT();
            glbClicks[Range_drawLineMode].x = x;
            glbClicks[Range_drawLineMode].y = y;
            glbClicks[Range_drawLineMode].atTime=atTime;
            glbClicks[Range_drawLineMode].atPrice=atPrice;
            
            if (Range_isDrawing) {
                Range_drawLineMode++;
                if (Range_drawLineMode == 1) {
                    
                    CreateHLine("Line2", 0, 0, 0, clrTurquoise);
                } else if (Range_drawLineMode == 2) {
                    Range_drawLineMode = 0;
                    Range_isDrawing = false;
                    hud.SetItemValue("draw_range", "R");
                    ObjectDelete(0, "Line1");
                    ObjectDelete(0, "Line2");
                }
            }
        }
    } else if (id == CHARTEVENT_MOUSE_MOVE) {
        if (!Range_mouseMoveEnabled) return;

        int subwindow, x = (int)lparam, y = (int)dparam;
        datetime atTime;
        double atPrice;
        ChartXYToTimePrice(0,x,y,subwindow,atTime,atPrice);

        ObjectMove(0, "Line" + (Range_drawLineMode+1), 0, atTime, atPrice);
        
        if (Range_isDrawing && Range_drawLineMode == 1) {
            Range_BuildRanges(MathMin(atPrice, glbClicks[0].atPrice), MathMax(atPrice, glbClicks[0].atPrice));
        }
    }
}

void Range_HandleKeyPress(HUD* hud, long lparam, double dparam, string sparam) {
    switch (lparam) {
        case KEY_R: 
            Range_isDrawing = !Range_isDrawing;
            Range_drawLineMode = 0;
            hud.SetItemValue("draw_range_line", "(Drawing, left-click to place range)");
         
            if (Range_isDrawing) {
                Range_mouseMoveEnabled = true;
                CreateHLine("Line1", 0.0, 0, 0, clrTurquoise);
            } else {
                Range_mouseMoveEnabled = false;
            }
         
            break;
        default:
            debuglog("Unmapped key:"+(string)lparam); 
            break;
    }
}

#property strict
#property indicator_chart_window

#include <FX/Logging.mqh>
#include <FX/Utility.mqh>
#include <FX/Draw.mqh>

sinput int RangeMatrix_resolution = 10;

string glbIndicatorTemporaryId;
struct ClickHistory {
   int x;
   int y;
   datetime atTime;
   double atPrice;
   datetime clickTimestamp;
};

int glbClickCount;
ClickHistory glbClicks[];


class Range {
public:
    double rangeLow;
    double rangeMid;
    double rangeHigh;

    static void Build(double baseRangeLow, double baseRangeHigh)
    {
        if (ArraySize(ranges) != 0) {
            // @TODO make more efficient. just move objects and set variables rather than deleting and recreating.
            Range::Destroy();
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
    
    static void Destroy()
    {
        for (int i = 0; i < ArraySize(ranges); i++) {
            ObjectDelete("Range" + (i+1) + "_Low");
            ObjectDelete("Range" + (i+1) + "_High");
            ObjectDelete("Range" + (i+1) + "_Mid");
    
            delete ranges[i];
        }
    
        ArrayResize(ranges, 0);
    }
};

Range* ranges[];

int OnInit()
{
    glbIndicatorTemporaryId = IntegerToString(GetMicrosecondCount());
    IndicatorSetString(INDICATOR_SHORTNAME, glbIndicatorTemporaryId);

    glbClickCount=0;

    double baseRangeLow = GlobalVariableGet("BaseRangeLow_" + Symbol());
    double baseRangeHigh = GlobalVariableGet("BaseRangeHigh_" + Symbol());

    if (baseRangeLow != 0 && baseRangeHigh != 0) {
        Range::Build(baseRangeLow, baseRangeHigh);
    }
   
   
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    Range::Destroy();
}

int OnCalculate(const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[])
{
   return(rates_total);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
    if (id == CHARTEVENT_KEYDOWN) {
    // Cancel the drawing if Esc is pressed
        if (lparam == 27) {
            glbClickCount = 0;
            RemoveIndicator();
        }
    } else if (id == CHARTEVENT_CLICK) {
        // Get the x-y coords of the click and convert them to time-price coords
        int subwindow, x=(int)lparam, y=(int)dparam;
        datetime atTime;
        double atPrice;
        ChartXYToTimePrice(0,x,y,subwindow,atTime,atPrice);
    
        if (subwindow != 0) {
            RemoveIndicator();
        } else {
            glbClickCount++;
    
            ArrayResize(glbClicks,glbClickCount);
            glbClicks[glbClickCount-1].clickTimestamp=TimeGMT();
            glbClicks[glbClickCount - 1].x = x;
            glbClicks[glbClickCount - 1].y = y;
            glbClicks[glbClickCount-1].atTime=atTime;
            glbClicks[glbClickCount-1].atPrice=atPrice;
    
            if (glbClickCount == 1 && ArraySize(ranges) == 0) {
                CreateHLine("Line1", glbClicks[0].atPrice, 0, 0, clrTurquoise);
                CreateHLine("Line2", 0, 0, 0, clrTurquoise);
             
                ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true);
            } else if (glbClickCount == 2) {
                ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,false);
 
                ObjectDelete(0, "Line1");
                ObjectDelete(0, "Line2");
            }
        }
    } else if (id == CHARTEVENT_MOUSE_MOVE) {
        int subwindow, x = (int)lparam, y = (int)dparam;
        datetime atTime;
        double atPrice;
        ChartXYToTimePrice(0,x,y,subwindow,atTime,atPrice);

        ObjectMove(0, "Line2", 0, atTime, atPrice);
        
        Range::Build(MathMin(atPrice, glbClicks[0].atPrice), MathMax(atPrice, glbClicks[0].atPrice));
    }
}


void RemoveIndicator()
{
    ObjectDelete(0, "Line1");
    ObjectDelete(0, "Line2");
    
    Range::Destroy();
}

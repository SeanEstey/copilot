//+------------------------------------------------------------------+
//|                      Fisher Transform                            |
//|                        original Fisher routine by Yura Prokofiev |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2017, Macdulio"
#property link      "http://macdulio.blogspot.co.uk"

#property indicator_separate_window
#property indicator_minimum -2
#property indicator_maximum 2
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red

//---- input parameters
extern int FisherPeriod   = 9;

//---- indicator buffers
double FishBuffer1[];
double FishBuffer2[];

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int deinit() {
   // ObjectsDeleteAll(0); 
   return(0);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int init()  {
   string short_name;
   
   //---- indicator lines
   IndicatorBuffers(2);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(0, FishBuffer1);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(1, FishBuffer2);
  
   ArrayInitialize(FishBuffer1, 0);
   ArrayInitialize(FishBuffer2, 0);

   short_name="Fisher Transform";
   IndicatorShortName(short_name);
   IndicatorDigits(3);
   
   SetIndexLabel(0, "Fish1");
   SetIndexLabel(1, "Fish2");
   
   SetIndexDrawBegin(0, FisherPeriod);
   SetIndexDrawBegin(1, FisherPeriod);
   
   return(0);
}

//+------------------------------------------------------------------+
// The amount of bars not changed after the indicator had been launched last. 
//+------------------------------------------------------------------+
int start() {
   int counted_bars = IndicatorCounted();
   if(counted_bars == 0) {
      for(int j=1; j<=FisherPeriod; j++) {
         FishBuffer1[Bars-j] = 0;
         FishBuffer2[Bars-j] = 0;
      }
   }
   
   int i = Bars - FisherPeriod;
   if(counted_bars > FisherPeriod)
      i=Bars-counted_bars-1;
   
   double MinL=0, MaxH=0, fVal1=0, fVal2=0, price=0;
   
   while(i>=0) {
      MaxH = High[Highest(NULL,0,MODE_HIGH,FisherPeriod,i)];
      MinL = Low[Lowest(NULL,0,MODE_LOW,FisherPeriod,i)];
      price = (High[i]+Low[i])/2;
      fVal1 = 0.33*2*((price-MinL)/(MaxH-MinL)-0.5) + 0.67*FishBuffer2[i+1];    
      fVal2 = MathMin(MathMax(fVal1,-0.999),0.999); 
      FishBuffer1[i] = 0.5*MathLog((1+fVal2)/(1-fVal2)) + 0.5*FishBuffer1[i+1];
      FishBuffer2[i] = fVal1;
      i--;
   }
   
   return(0);   
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void dump() {
   //Print("start(): counted_bars=", counted_bars, ", i=", i, ", Bars=", Bars);
   
   for(int k=0; k<ArraySize(FishBuffer1); k++) {
      Print("FishBuffer1[", k, "]=", FishBuffer1[k]);
   }
}

//+------------------------------------------------------------------+
//|                                               rsi chart bars.mq4 |
//|                                   Copyright � 2008, thestellaman |
//|                            thestellamanrulestheworld@yahoo.co.uk |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2008, thestellaman"
#property link      "http://www.thestellamanrulestheworld.com"

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_color1 Blue//wick
#property indicator_color2 Red//wick
#property indicator_color3 Blue//candle
#property indicator_color4 Red//candle
#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 3
#property indicator_width4 3


//---- stoch settings
extern int	EMA_Period		= 21;
extern int  EMA_Price      = 0;
extern int  EMA_Mode       = 1;


//---- input parameters
extern int	BarWidth			= 1,
				CandleWidth		= 3;

//---- buffers
double Bar1[],
		 Bar2[],
		 Candle1[],
		 Candle2[];
		 

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
{
//---- indicators
	IndicatorShortName("EMA Candles:("+	EMA_Period+")");
	IndicatorBuffers(4);
	SetIndexBuffer(0,Bar1);
	SetIndexBuffer(1,Bar2);				
	SetIndexBuffer(2,Candle1);
	SetIndexBuffer(3,Candle2);
	SetIndexStyle(0,DRAW_HISTOGRAM,0,BarWidth);
	SetIndexStyle(1,DRAW_HISTOGRAM,0,BarWidth);
	SetIndexStyle(2,DRAW_HISTOGRAM,0,CandleWidth);
	SetIndexStyle(3,DRAW_HISTOGRAM,0,CandleWidth);

	return(0);
}

//+------------------------------------------------------------------+
double EMA  	(int i = 0)	{return(iMA(NULL,0,EMA_Period,0,EMA_Mode,EMA_Price,i));}



//+------------------------------------------------------------------+
void SetCandleColor(int col, int i)
{
	double high,low,bodyHigh,bodyLow;


	{
		bodyHigh = MathMax(Open[i],Close[i]);
		bodyLow  = MathMin(Open[i],Close[i]);
		high		= High[i];
		low		= Low[i];
	}

	Bar1[i] = low;	Candle1[i] = bodyLow;
	Bar2[i] = low;	Candle2[i] = bodyLow;
	

	switch(col)
	{
		case 1: 	Bar1[i] = high;	Candle1[i] = bodyHigh;	break;
		case 2: 	Bar2[i] = high;	Candle2[i] = bodyHigh;	break;
	
	}
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
{
	for(int i = MathMax(Bars-1-IndicatorCounted(),1); i>=0; i--)
	{
		double	ema	= EMA(i);
				

				if(ema > Close[i])		SetCandleColor(1,i);
		else	if(ema < Close[i])		SetCandleColor(2,i);
		
	}
	

	return(0);
}
//+------------------------------------------------------------------+


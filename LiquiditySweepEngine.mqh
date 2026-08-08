#ifndef __SCALPINGEA_LIQUIDITY_SWEEP_ENGINE_MQH__
#define __SCALPINGEA_LIQUIDITY_SWEEP_ENGINE_MQH__

#include "Constants.mqh"
#include "Structures.mqh"


//+------------------------------------------------------------------+
//| Settings                                                         |
//+------------------------------------------------------------------+

input group "=== H4 / H1 Liquidity ==="

input int InpH4LiquidityLookback = 3;
input int InpH1LiquidityLookback = 3;
input int InpHTFLiquiditySearchBars = 100;


input group "=== Session Liquidity ==="

input int InpAsiaStartHour = 0;
input int InpAsiaEndHour = 7;

input int InpLondonStartHour = 8;
input int InpLondonEndHour = 12;

input int InpNewYorkStartHour = 13;
input int InpNewYorkEndHour = 17;


input group "=== Liquidity Sweep Validation ==="

input double InpMinimumSweepATR = 0.05;
input double InpMaximumSweepATR = 1.50;

input double InpMinimumBodyPercent = 0.35;
input double InpMinimumWickPercent = 0.30;

input int InpMaximumLiquidityAge = 100;


//+------------------------------------------------------------------+
//| Reset                                                            |
//+------------------------------------------------------------------+

void ResetLiquidityEnvironment()
{
   ZeroMemory(g_LiquidityEnvironment);
   ZeroMemory(g_Liquidity);

   g_Liquidity.valid = false;
   g_LiquidityEnvironment.valid = false;
}


//+------------------------------------------------------------------+
//| Swing High                                                       |
//+------------------------------------------------------------------+

bool IsLiquiditySwingHigh(
   ENUM_TIMEFRAMES timeframe,
   int shift,
   int lookback
)
{
   if(shift <= lookback)
      return false;

   double high = iHigh(_Symbol, timeframe, shift);

   if(high <= 0.0)
      return false;

   for(int i = 1; i <= lookback; i++)
   {
      if(high <= iHigh(_Symbol, timeframe, shift - i))
         return false;

      if(high <= iHigh(_Symbol, timeframe, shift + i))
         return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//| Swing Low                                                        |
//+------------------------------------------------------------------+

bool IsLiquiditySwingLow(
   ENUM_TIMEFRAMES timeframe,
   int shift,
   int lookback
)
{
   if(shift <= lookback)
      return false;

   double low = iLow(_Symbol, timeframe, shift);

   if(low <= 0.0)
      return false;

   for(int i = 1; i <= lookback; i++)
   {
      if(low >= iLow(_Symbol, timeframe, shift - i))
         return false;

      if(low >= iLow(_Symbol, timeframe, shift + i))
         return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//| Find HTF Swing High                                              |
//+------------------------------------------------------------------+

bool FindHTFSwingHigh(
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   double &price,
   int &shift,
   datetime &time
)
{
   int bars = Bars(_Symbol, timeframe);

   if(bars <= lookback * 2 + 5)
      return false;

   int maxBars = MathMin(
      InpHTFLiquiditySearchBars,
      bars - lookback - 1
   );

   for(int s = lookback + 1; s <= maxBars; s++)
   {
      if(!IsLiquiditySwingHigh(timeframe, s, lookback))
         continue;

      price = iHigh(_Symbol, timeframe, s);
      shift = s;
      time = iTime(_Symbol, timeframe, s);

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Find HTF Swing Low                                               |
//+------------------------------------------------------------------+

bool FindHTFSwingLow(
   ENUM_TIMEFRAMES timeframe,
   int lookback,
   double &price,
   int &shift,
   datetime &time
)
{
   int bars = Bars(_Symbol, timeframe);

   if(bars <= lookback * 2 + 5)
      return false;

   int maxBars = MathMin(
      InpHTFLiquiditySearchBars,
      bars - lookback - 1
   );

   for(int s = lookback + 1; s <= maxBars; s++)
   {
      if(!IsLiquiditySwingLow(timeframe, s, lookback))
         continue;

      price = iLow(_Symbol, timeframe, s);
      shift = s;
      time = iTime(_Symbol, timeframe, s);

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ATR                                                              |
//+------------------------------------------------------------------+

double GetLiquidityATR(ENUM_TIMEFRAMES timeframe)
{
   int handle = iATR(_Symbol, timeframe, 14);

   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   double value = 0.0;

   if(CopyBuffer(handle, 0, 1, 1, buffer) == 1)
      value = buffer[0];

   IndicatorRelease(handle);

   return value;
}


//+------------------------------------------------------------------+
//| Candle Data                                                      |
//+------------------------------------------------------------------+

bool GetCandleData(
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double &open,
   double &high,
   double &low,
   double &close,
   double &range,
   double &body,
   double &upperWick,
   double &lowerWick
)
{
   open  = iOpen(_Symbol, timeframe, shift);
   high  = iHigh(_Symbol, timeframe, shift);
   low   = iLow(_Symbol, timeframe, shift);
   close = iClose(_Symbol, timeframe, shift);

   range = high - low;

   if(range <= 0.0)
      return false;

   body = MathAbs(close - open);

   upperWick =
      high - MathMax(open, close);

   lowerWick =
      MathMin(open, close) - low;

   return true;
}


//+------------------------------------------------------------------+
//| Phase 3 Confirmation                                             |
//|                                                                  |
//| Five possible confirmations:                                    |
//| 1. Displacement                                                  |
//| 2. MSS                                                            |
//| 3. BOS                                                            |
//| 4. CHOCH                                                          |
//| 5. IFVG                                                           |
//|                                                                  |
//| IMPORTANT:                                                        |
//| One or two confirmations are enough.                             |
//+------------------------------------------------------------------+

void EvaluatePhase3Confirmations(
   LiquiditySweepState &result
)
{
   result.displacementConfirmed =
      result.displacement;

   // These are intentionally false here.
   // M5 structure engine will calculate them later.
   result.mssConfirmed   = false;
   result.bosConfirmed   = false;
   result.chochConfirmed = false;
   result.ifvgConfirmed  = false;

   result.confirmationCount = 0;

   if(result.displacementConfirmed)
      result.confirmationCount++;

   if(result.mssConfirmed)
      result.confirmationCount++;

   if(result.bosConfirmed)
      result.confirmationCount++;

   if(result.chochConfirmed)
      result.confirmationCount++;

   if(result.ifvgConfirmed)
      result.confirmationCount++;

   // At this stage displacement alone can validate Phase 3.
   // Once the M5 confirmation engine exists, MSS/BOS/CHoCH/IFVG
   // will contribute here as well.

   result.phase3Confirmed =
      result.confirmationCount >= 1;
}


//+------------------------------------------------------------------+
//| Validate Liquidity Sweep                                         |
//+------------------------------------------------------------------+

bool ValidateLiquiditySweep(
   ENUM_TIMEFRAMES timeframe,
   ENUM_LIQUIDITY_TYPE type,
   double liquidityPrice,
   int liquidityShift,
   int sweepShift,
   LiquiditySweepState &result
)
{
   ZeroMemory(result);

   double open;
   double high;
   double low;
   double close;
   double range;
   double body;
   double upperWick;
   double lowerWick;

   if(!GetCandleData(
      timeframe,
      sweepShift,
      open,
      high,
      low,
      close,
      range,
      body,
      upperWick,
      lowerWick
   ))
      return false;

   double atr = GetLiquidityATR(timeframe);

   if(atr <= 0.0)
      return false;


   //===============================================================
   // SELL-SIDE LIQUIDITY
   //===============================================================

   if(type == LIQUIDITY_SELL_SIDE)
   {
      if(low >= liquidityPrice)
         return false;

      double penetration =
         liquidityPrice - low;

      if(penetration < atr * InpMinimumSweepATR)
         return false;

      if(penetration > atr * InpMaximumSweepATR)
         return false;

      if(close <= liquidityPrice)
         return false;

      double wickPercent =
         lowerWick / range;

      double bodyPercent =
         body / range;

      result.strongRejection =
         wickPercent >= InpMinimumWickPercent;

      result.displacement =
         close > open &&
         bodyPercent >= InpMinimumBodyPercent;

      if(!result.strongRejection &&
         !result.displacement)
         return false;

      result.direction = BIAS_BULLISH;
      result.penetration = penetration;
      result.rejectionDistance = penetration;
   }


   //===============================================================
   // BUY-SIDE LIQUIDITY
   //===============================================================

   else if(type == LIQUIDITY_BUY_SIDE)
   {
      if(high <= liquidityPrice)
         return false;

      double penetration =
         high - liquidityPrice;

      if(penetration < atr * InpMinimumSweepATR)
         return false;

      if(penetration > atr * InpMaximumSweepATR)
         return false;

      if(close >= liquidityPrice)
         return false;

      double wickPercent =
         upperWick / range;

      double bodyPercent =
         body / range;

      result.strongRejection =
         wickPercent >= InpMinimumWickPercent;

      result.displacement =
         close < open &&
         bodyPercent >= InpMinimumBodyPercent;

      if(!result.strongRejection &&
         !result.displacement)
         return false;

      result.direction = BIAS_BEARISH;
      result.penetration = penetration;
      result.rejectionDistance = penetration;
   }
   else
   {
      return false;
   }


   //===============================================================
   // Fill
   //===============================================================

   result.valid = true;
   result.type = type;

   result.liquidityPrice = liquidityPrice;

   result.liquidityTime =
      iTime(_Symbol, timeframe, liquidityShift);

   result.sweepTime =
      iTime(_Symbol, timeframe, sweepShift);

   result.sourceTimeframe = timeframe;

   result.sweepHigh = high;
   result.sweepLow = low;

   result.candleOpen = open;
   result.candleHigh = high;
   result.candleLow = low;
   result.candleClose = close;

   result.candleRange = range;
   result.bodySize = body;

   result.upperWick = upperWick;
   result.lowerWick = lowerWick;

   result.closedBackInside = true;
   result.meaningfulLiquidity = true;

   result.liquidityAge = liquidityShift;

   result.oldLiquidity =
      liquidityShift > InpMaximumLiquidityAge;

   result.inducementRisk =
      result.oldLiquidity;


   //===============================================================
   // Phase 3
   //===============================================================

   EvaluatePhase3Confirmations(result);


   //===============================================================
   // Quality
   //===============================================================

   result.quality = SWEEP_VALID;

   if(result.strongRejection &&
      result.displacement)
   {
      result.quality = SWEEP_STRONG;
   }


   //===============================================================
   // Score
   //===============================================================

   result.score = 25;

   if(result.strongRejection)
      result.score += 25;

   if(result.displacement)
      result.score += 25;

   if(result.closedBackInside)
      result.score += 15;

   if(!result.oldLiquidity)
      result.score += 10;

   if(result.score > 100)
      result.score = 100;

   return true;
}


//+------------------------------------------------------------------+
//| Scan H4                                                          |
//+------------------------------------------------------------------+

bool ScanH4Liquidity(LiquiditySweepState &result)
{
   ZeroMemory(result);

   double highPrice;
   double lowPrice;

   int highShift;
   int lowShift;

   datetime highTime;
   datetime lowTime;

   bool foundHigh =
      FindHTFSwingHigh(
         PERIOD_H4,
         InpH4LiquidityLookback,
         highPrice,
         highShift,
         highTime
      );

   bool foundLow =
      FindHTFSwingLow(
         PERIOD_H4,
         InpH4LiquidityLookback,
         lowPrice,
         lowShift,
         lowTime
      );


   if(foundHigh)
   {
      LiquiditySweepState candidate;

      if(ValidateLiquiditySweep(
         PERIOD_H4,
         LIQUIDITY_BUY_SIDE,
         highPrice,
         highShift,
         1,
         candidate
      ))
      {
         candidate.h4Liquidity = true;
         result = candidate;
         return true;
      }
   }


   if(foundLow)
   {
      LiquiditySweepState candidate;

      if(ValidateLiquiditySweep(
         PERIOD_H4,
         LIQUIDITY_SELL_SIDE,
         lowPrice,
         lowShift,
         1,
         candidate
      ))
      {
         candidate.h4Liquidity = true;
         result = candidate;
         return true;
      }
   }

   return false;
}


//+------------------------------------------------------------------+
//| Scan H1                                                          |
//+------------------------------------------------------------------+

bool ScanH1Liquidity(LiquiditySweepState &result)
{
   ZeroMemory(result);

   double highPrice;
   double lowPrice;

   int highShift;
   int lowShift;

   datetime highTime;
   datetime lowTime;

   bool foundHigh =
      FindHTFSwingHigh(
         PERIOD_H1,
         InpH1LiquidityLookback,
         highPrice,
         highShift,
         highTime
      );

   bool foundLow =
      FindHTFSwingLow(
         PERIOD_H1,
         InpH1LiquidityLookback,
         lowPrice,
         lowShift,
         lowTime
      );


   if(foundHigh)
   {
      LiquiditySweepState candidate;

      if(ValidateLiquiditySweep(
         PERIOD_H1,
         LIQUIDITY_BUY_SIDE,
         highPrice,
         highShift,
         1,
         candidate
      ))
      {
         candidate.h1Liquidity = true;
         result = candidate;
         return true;
      }
   }


   if(foundLow)
   {
      LiquiditySweepState candidate;

      if(ValidateLiquiditySweep(
         PERIOD_H1,
         LIQUIDITY_SELL_SIDE,
         lowPrice,
         lowShift,
         1,
         candidate
      ))
      {
         candidate.h1Liquidity = true;
         result = candidate;
         return true;
      }
   }

   return false;
}


//+------------------------------------------------------------------+
//| Session Range                                                    |
//+------------------------------------------------------------------+

bool GetSessionRange(
   int startHour,
   int endHour,
   double &sessionHigh,
   double &sessionLow
)
{
   sessionHigh = 0.0;
   sessionLow = 0.0;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;

   datetime dayStart = StructToTime(dt);

   datetime sessionStart =
      dayStart + startHour * 3600;

   datetime sessionEnd =
      dayStart + endHour * 3600;

   if(sessionEnd <= sessionStart)
      sessionEnd += 86400;

   if(TimeCurrent() <= sessionEnd)
      return false;

   int startShift =
      iBarShift(
         _Symbol,
         PERIOD_M5,
         sessionStart,
         false
      );

   int endShift =
      iBarShift(
         _Symbol,
         PERIOD_M5,
         sessionEnd,
         false
      );

   if(startShift < 0 || endShift < 0)
      return false;

   int fromShift = MathMin(startShift, endShift);
   int toShift = MathMax(startShift, endShift);

   for(int shift = fromShift;
       shift <= toShift;
       shift++)
   {
      double high =
         iHigh(_Symbol, PERIOD_M5, shift);

      double low =
         iLow(_Symbol, PERIOD_M5, shift);

      if(high <= 0.0 || low <= 0.0)
         continue;

      if(sessionHigh == 0.0 ||
         high > sessionHigh)
      {
         sessionHigh = high;
      }

      if(sessionLow == 0.0 ||
         low < sessionLow)
      {
         sessionLow = low;
      }
   }

   return sessionHigh > 0.0 &&
          sessionLow > 0.0;
}


//+------------------------------------------------------------------+
//| Session Sweep                                                    |
//+------------------------------------------------------------------+

bool CheckSessionSweep(
   double liquidityPrice,
   ENUM_LIQUIDITY_TYPE type,
   string sessionName,
   LiquiditySweepState &result
)
{
   ZeroMemory(result);

   double open;
   double high;
   double low;
   double close;
   double range;
   double body;
   double upperWick;
   double lowerWick;

   if(!GetCandleData(
      PERIOD_M5,
      1,
      open,
      high,
      low,
      close,
      range,
      body,
      upperWick,
      lowerWick
   ))
      return false;

   double atr = GetLiquidityATR(PERIOD_M5);

   if(atr <= 0.0)
      return false;


   double penetration = 0.0;


   //--- Sell-side

   if(type == LIQUIDITY_SELL_SIDE)
   {
      if(low >= liquidityPrice)
         return false;

      penetration =
         liquidityPrice - low;

      if(penetration < atr * InpMinimumSweepATR)
         return false;

      if(penetration > atr * InpMaximumSweepATR)
         return false;

      if(close <= liquidityPrice)
         return false;

      result.direction = BIAS_BULLISH;

      result.strongRejection =
         (lowerWick / range) >=
         InpMinimumWickPercent;

      result.displacement =
         close > open &&
         (body / range) >=
         InpMinimumBodyPercent;
   }


   //--- Buy-side

   else if(type == LIQUIDITY_BUY_SIDE)
   {
      if(high <= liquidityPrice)
         return false;

      penetration =
         high - liquidityPrice;

      if(penetration < atr * InpMinimumSweepATR)
         return false;

      if(penetration > atr * InpMaximumSweepATR)
         return false;

      if(close >= liquidityPrice)
         return false;

      result.direction = BIAS_BEARISH;

      result.strongRejection =
         (upperWick / range) >=
         InpMinimumWickPercent;

      result.displacement =
         close < open &&
         (body / range) >=
         InpMinimumBodyPercent;
   }
   else
   {
      return false;
   }


   if(!result.strongRejection &&
      !result.displacement)
   {
      return false;
   }


   //===============================================================
   // Fill
   //===============================================================

   result.valid = true;
   result.type = type;

   result.liquidityPrice =
      liquidityPrice;

   result.penetration =
      penetration;

   result.rejectionDistance =
      penetration;

   result.sweepTime =
      iTime(_Symbol, PERIOD_M5, 1);

   result.liquidityTime =
      result.sweepTime;

   result.sourceTimeframe =
      PERIOD_M5;

   result.sweepHigh = high;
   result.sweepLow = low;

   result.candleOpen = open;
   result.candleHigh = high;
   result.candleLow = low;
   result.candleClose = close;

   result.candleRange = range;
   result.bodySize = body;

   result.upperWick = upperWick;
   result.lowerWick = lowerWick;

   result.closedBackInside = true;
   result.meaningfulLiquidity = true;

   result.oldLiquidity = false;
   result.inducementRisk = false;

   result.sessionLiquidity = true;

   if(sessionName == "ASIA")
      result.asiaLiquidity = true;

   if(sessionName == "LONDON")
      result.londonLiquidity = true;

   if(sessionName == "NEW YORK")
      result.newYorkLiquidity = true;


   //===============================================================
   // Phase 3
   //===============================================================

   EvaluatePhase3Confirmations(result);


   //===============================================================
   // Quality / Score
   //===============================================================

   result.quality = SWEEP_VALID;

   result.score = 70;

   if(result.strongRejection)
      result.score += 15;

   if(result.displacement)
      result.score += 15;

   if(result.score > 100)
      result.score = 100;

   if(result.strongRejection &&
      result.displacement)
   {
      result.quality = SWEEP_STRONG;
   }

   return true;
}


//+------------------------------------------------------------------+
//| Scan Session Liquidity                                           |
//+------------------------------------------------------------------+

bool ScanSessionLiquidity(LiquiditySweepState &result)
{
   ZeroMemory(result);


   //===============================================================
   // ASIA
   //===============================================================

   double asiaHigh;
   double asiaLow;

   if(GetSessionRange(
      InpAsiaStartHour,
      InpAsiaEndHour,
      asiaHigh,
      asiaLow
   ))
   {
      if(CheckSessionSweep(
         asiaLow,
         LIQUIDITY_SELL_SIDE,
         "ASIA",
         result
      ))
         return true;

      if(CheckSessionSweep(
         asiaHigh,
         LIQUIDITY_BUY_SIDE,
         "ASIA",
         result
      ))
         return true;
   }


   //===============================================================
   // LONDON
   //===============================================================

   double londonHigh;
   double londonLow;

   if(GetSessionRange(
      InpLondonStartHour,
      InpLondonEndHour,
      londonHigh,
      londonLow
   ))
   {
      if(CheckSessionSweep(
         londonLow,
         LIQUIDITY_SELL_SIDE,
         "LONDON",
         result
      ))
         return true;

      if(CheckSessionSweep(
         londonHigh,
         LIQUIDITY_BUY_SIDE,
         "LONDON",
         result
      ))
         return true;
   }


   //===============================================================
   // NEW YORK
   //===============================================================

   double newYorkHigh;
   double newYorkLow;

   if(GetSessionRange(
      InpNewYorkStartHour,
      InpNewYorkEndHour,
      newYorkHigh,
      newYorkLow
   ))
   {
      if(CheckSessionSweep(
         newYorkLow,
         LIQUIDITY_SELL_SIDE,
         "NEW YORK",
         result
      ))
         return true;

      if(CheckSessionSweep(
         newYorkHigh,
         LIQUIDITY_BUY_SIDE,
         "NEW YORK",
         result
      ))
         return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Copy Sweep Into Environment                                      |
//+------------------------------------------------------------------+

void CopySweepToEnvironment(
   LiquiditySweepState &source
)
{
   if(!source.valid)
      return;

   if(source.h4Liquidity)
   {
      g_LiquidityEnvironment.h4.valid = true;
      g_LiquidityEnvironment.h4.direction =
         source.direction;
      g_LiquidityEnvironment.h4.sweptPrice =
         source.liquidityPrice;
      g_LiquidityEnvironment.h4.sweepTime =
         source.sweepTime;
      g_LiquidityEnvironment.h4.sweepType =
         source.type;
      g_LiquidityEnvironment.h4.quality =
         source.quality;

      if(source.type == LIQUIDITY_BUY_SIDE)
         g_LiquidityEnvironment.h4.buySideSwept = true;
      else
         g_LiquidityEnvironment.h4.sellSideSwept = true;

      g_LiquidityEnvironment.h4Confirmed = true;
   }

   if(source.h1Liquidity)
   {
      g_LiquidityEnvironment.h1.valid = true;
      g_LiquidityEnvironment.h1.direction =
         source.direction;
      g_LiquidityEnvironment.h1.sweptPrice =
         source.liquidityPrice;
      g_LiquidityEnvironment.h1.sweepTime =
         source.sweepTime;
      g_LiquidityEnvironment.h1.sweepType =
         source.type;
      g_LiquidityEnvironment.h1.quality =
         source.quality;

      if(source.type == LIQUIDITY_BUY_SIDE)
         g_LiquidityEnvironment.h1.buySideSwept = true;
      else
         g_LiquidityEnvironment.h1.sellSideSwept = true;

      g_LiquidityEnvironment.h1Confirmed = true;
   }

   if(source.sessionLiquidity)
   {
      g_LiquidityEnvironment.session.valid = true;
      g_LiquidityEnvironment.session.direction =
         source.direction;
      g_LiquidityEnvironment.session.sweptPrice =
         source.liquidityPrice;
      g_LiquidityEnvironment.session.sweepTime =
         source.sweepTime;
      g_LiquidityEnvironment.session.sweepType =
         source.type;
      g_LiquidityEnvironment.session.quality =
         source.quality;

      if(source.type == LIQUIDITY_BUY_SIDE)
         g_LiquidityEnvironment.session.buySideSwept = true;
      else
         g_LiquidityEnvironment.session.sellSideSwept = true;

      g_LiquidityEnvironment.sessionConfirmed = true;
   }
}


//+------------------------------------------------------------------+
//| Select Strongest Liquidity Sweep                                 |
//+------------------------------------------------------------------+

bool SelectBestLiquiditySweep()
{
   LiquiditySweepState best;
   ZeroMemory(best);

   bool found = false;


   //===============================================================
   // H4
   //===============================================================

   LiquiditySweepState h4;

   if(ScanH4Liquidity(h4))
   {
      g_LiquidityEnvironment.h4.valid = true;

      CopySweepToEnvironment(h4);

      if(!found || h4.score > best.score)
      {
         best = h4;
         found = true;
      }
   }


   //===============================================================
   // H1
   //===============================================================

   LiquiditySweepState h1;

   if(ScanH1Liquidity(h1))
   {
      g_LiquidityEnvironment.h1.valid = true;

      CopySweepToEnvironment(h1);

      if(!found || h1.score > best.score)
      {
         best = h1;
         found = true;
      }
   }


   //===============================================================
   // Session
   //===============================================================

   LiquiditySweepState session;

   if(ScanSessionLiquidity(session))
   {
      g_LiquidityEnvironment.session.valid = true;

      CopySweepToEnvironment(session);

      if(!found || session.score > best.score)
      {
         best = session;
         found = true;
      }
   }


   //===============================================================
   // Nothing found
   //===============================================================

   if(!found)
   {
      g_Liquidity.valid = false;
      g_LiquidityEnvironment.valid = false;
      g_LiquidityEnvironment.selected = false;

      return false;
   }


   //===============================================================
   // Selected liquidity
   //===============================================================

   g_Liquidity = best;

   g_Liquidity.valid = true;

   g_LiquidityEnvironment.valid = true;
   g_LiquidityEnvironment.selected = true;

   g_LiquidityEnvironment.selectedType =
      best.type;

   g_LiquidityEnvironment.selectedDirection =
      best.direction;

   g_LiquidityEnvironment.selectedTimeframe =
      best.sourceTimeframe;

   g_LiquidityEnvironment.selectedPrice =
      best.liquidityPrice;

   g_LiquidityEnvironment.selectedTime =
      best.sweepTime;

   g_LiquidityEnvironment.selectedQuality =
      best.quality;

   g_LiquidityEnvironment.selectedScore =
      best.score;

   g_LiquidityEnvironment.confirmedSweepCount = 0;

   if(g_LiquidityEnvironment.h4Confirmed)
      g_LiquidityEnvironment.confirmedSweepCount++;

   if(g_LiquidityEnvironment.h1Confirmed)
      g_LiquidityEnvironment.confirmedSweepCount++;

   if(g_LiquidityEnvironment.sessionConfirmed)
      g_LiquidityEnvironment.confirmedSweepCount++;

   return true;
}


//+------------------------------------------------------------------+
//| Main Liquidity Scan                                              |
//+------------------------------------------------------------------+

void ScanLiquidity()
{
   ResetLiquidityEnvironment();

   SelectBestLiquiditySweep();
}


//+------------------------------------------------------------------+

#endif
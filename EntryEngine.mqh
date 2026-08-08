#ifndef __SCALPINGEA_ENTRY_ENGINE_MQH__
#define __SCALPINGEA_ENTRY_ENGINE_MQH__

#include "Constants.mqh"
#include "Structures.mqh"

EntryConfirmationState g_Entry;


//+------------------------------------------------------------------+
//| Entry Engine Settings                                            |
//+------------------------------------------------------------------+

input group "=== Entry Confirmation ==="

input bool   InpUseM5EntryConfirmation = true;
input bool   InpUseM1EntryConfirmation = true;

input double InpEntryMinimumWickPercent = 0.30;
input double InpEntryMinimumBodyPercent = 0.20;

input double InpEntryMinimumRejectionATR = 0.05;

input double InpEntryStopBufferATR = 0.10;

input double InpEntryRiskReward = 3.0;

input int InpEntryMaxBarsAfterOB = 20;


//+------------------------------------------------------------------+
//| Reset Entry State                                                |
//+------------------------------------------------------------------+

void ResetEntryState()
{
   ZeroMemory(g_Entry);

   g_Entry.valid = false;
}


//+------------------------------------------------------------------+
//| Get ATR for Entry Timeframe                                     |
//+------------------------------------------------------------------+

double GetEntryATR(
   ENUM_TIMEFRAMES timeframe
)
{
   int handle =
      iATR(
         _Symbol,
         timeframe,
         14
      );

   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];

   ArraySetAsSeries(
      buffer,
      true
   );

   double atr = 0.0;

   if(CopyBuffer(
         handle,
         0,
         1,
         1,
         buffer
      ) == 1)
   {
      atr = buffer[0];
   }

   IndicatorRelease(handle);

   return atr;
}


//+------------------------------------------------------------------+
//| Check price inside OB                                            |
//+------------------------------------------------------------------+

bool IsPriceInsideOrderBlock(
   double price,
   double obHigh,
   double obLow
)
{
   if(obHigh <= obLow)
      return false;

   return (
      price >= obLow &&
      price <= obHigh
   );
}


//+------------------------------------------------------------------+
//| Check candle touches OB                                          |
//+------------------------------------------------------------------+

bool CandleTouchesOrderBlock(
   ENUM_TIMEFRAMES timeframe,
   int shift,
   double obHigh,
   double obLow
)
{
   double high =
      iHigh(
         _Symbol,
         timeframe,
         shift
      );

   double low =
      iLow(
         _Symbol,
         timeframe,
         shift
      );

   if(high <= 0.0 ||
      low <= 0.0)
   {
      return false;
   }

   if(high < obLow)
      return false;

   if(low > obHigh)
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| Candle rejection                                                 |
//+------------------------------------------------------------------+

bool IsRejectionCandle(
   ENUM_TIMEFRAMES timeframe,
   int shift,
   ENUM_BIAS direction,
   double &wick,
   double &body
)
{
   double open =
      iOpen(
         _Symbol,
         timeframe,
         shift
      );

   double high =
      iHigh(
         _Symbol,
         timeframe,
         shift
      );

   double low =
      iLow(
         _Symbol,
         timeframe,
         shift
      );

   double close =
      iClose(
         _Symbol,
         timeframe,
         shift
      );

   double range =
      high - low;

   if(range <= 0.0)
      return false;

   body =
      MathAbs(
         close - open
      );

   double upperWick =
      high -
      MathMax(
         open,
         close
      );

   double lowerWick =
      MathMin(
         open,
         close
      ) - low;

   double atr =
      GetEntryATR(
         timeframe
      );

   if(atr <= 0.0)
      return false;


   //===============================================================
   // BULLISH REJECTION
   //===============================================================

   if(direction == BIAS_BULLISH)
   {
      wick = lowerWick;

      double wickPercent =
         lowerWick / range;

      double bodyPercent =
         body / range;

      bool directionalClose =
         close > open;

      bool sufficientWick =
         wickPercent >=
         InpEntryMinimumWickPercent;

      bool sufficientBody =
         bodyPercent >=
         InpEntryMinimumBodyPercent;

      bool sufficientSize =
         lowerWick >=
         atr * InpEntryMinimumRejectionATR;

      if(directionalClose &&
         sufficientWick &&
         sufficientSize)
      {
         return true;
      }

      // Strong rejection can also close neutral/slightly bearish
      // as long as the lower wick dominates.
      if(sufficientWick &&
         sufficientSize &&
         lowerWick > upperWick &&
         bodyPercent >=
         InpEntryMinimumBodyPercent)
      {
         return true;
      }

      return false;
   }


   //===============================================================
   // BEARISH REJECTION
   //===============================================================

   if(direction == BIAS_BEARISH)
   {
      wick = upperWick;

      double wickPercent =
         upperWick / range;

      double bodyPercent =
         body / range;

      bool directionalClose =
         close < open;

      bool sufficientWick =
         wickPercent >=
         InpEntryMinimumWickPercent;

      bool sufficientBody =
         bodyPercent >=
         InpEntryMinimumBodyPercent;

      bool sufficientSize =
         upperWick >=
         atr * InpEntryMinimumRejectionATR;

      if(directionalClose &&
         sufficientWick &&
         sufficientSize)
      {
         return true;
      }

      if(sufficientWick &&
         sufficientSize &&
         upperWick > lowerWick &&
         bodyPercent >=
         InpEntryMinimumBodyPercent)
      {
         return true;
      }

      return false;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Find M5 rejection                                                |
//+------------------------------------------------------------------+

bool FindM5Rejection(
   OrderBlockState &ob,
   double &rejectionHigh,
   double &rejectionLow,
   double &rejectionWick,
   double &rejectionBody,
   datetime &confirmationTime
)
{
   rejectionHigh = 0.0;
   rejectionLow = 0.0;
   rejectionWick = 0.0;
   rejectionBody = 0.0;
   confirmationTime = 0;

   if(!ob.valid)
      return false;

   if(!ob.fresh)
      return false;

   if(!ob.unmitigated)
      return false;


   int maxBars =
      MathMin(
         InpEntryMaxBarsAfterOB,
         ob.shift - 1
      );

   if(maxBars < 1)
      return false;


   //===============================================================
   // Scan candles after OB creation.
   //
   // shift 1 = latest closed M5 candle.
   //===============================================================

   for(int shift = 1;
       shift <= maxBars;
       shift++)
   {
      if(!CandleTouchesOrderBlock(
            PERIOD_M5,
            shift,
            ob.high,
            ob.low
         ))
      {
         continue;
      }

      double wick = 0.0;
      double body = 0.0;

      if(!IsRejectionCandle(
            PERIOD_M5,
            shift,
            ob.direction,
            wick,
            body
         ))
      {
         continue;
      }


      rejectionHigh =
         iHigh(
            _Symbol,
            PERIOD_M5,
            shift
         );

      rejectionLow =
         iLow(
            _Symbol,
            PERIOD_M5,
            shift
         );

      rejectionWick =
         wick;

      rejectionBody =
         body;

      confirmationTime =
         iTime(
            _Symbol,
            PERIOD_M5,
            shift
         );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Find M1 rejection                                                |
//|                                                                  |
//| M1 is OPTIONAL confirmation only.                                |
//| It never creates the setup by itself.                            |
//+------------------------------------------------------------------+

bool FindM1Rejection(
   OrderBlockState &ob,
   double &rejectionHigh,
   double &rejectionLow,
   double &rejectionWick,
   double &rejectionBody,
   datetime &confirmationTime
)
{
   rejectionHigh = 0.0;
   rejectionLow = 0.0;
   rejectionWick = 0.0;
   rejectionBody = 0.0;
   confirmationTime = 0;

   if(!ob.valid)
      return false;


   //===============================================================
   // Only inspect recent M1 candles.
   //===============================================================

   int maxBars = 15;

   for(int shift = 1;
       shift <= maxBars;
       shift++)
   {
      if(!CandleTouchesOrderBlock(
            PERIOD_M1,
            shift,
            ob.high,
            ob.low
         ))
      {
         continue;
      }

      double wick = 0.0;
      double body = 0.0;

      if(!IsRejectionCandle(
            PERIOD_M1,
            shift,
            ob.direction,
            wick,
            body
         ))
      {
         continue;
      }


      rejectionHigh =
         iHigh(
            _Symbol,
            PERIOD_M1,
            shift
         );

      rejectionLow =
         iLow(
            _Symbol,
            PERIOD_M1,
            shift
         );

      rejectionWick =
         wick;

      rejectionBody =
         body;

      confirmationTime =
         iTime(
            _Symbol,
            PERIOD_M1,
            shift
         );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+

double CalculateEntryStopLoss(
   OrderBlockState &ob
)
{
   double atr =
      GetEntryATR(
         PERIOD_M5
      );

   if(atr <= 0.0)
      return 0.0;

   double buffer =
      atr *
      InpEntryStopBufferATR;


   if(ob.direction == BIAS_BULLISH)
   {
      return (
         ob.low -
         buffer
      );
   }


   if(ob.direction == BIAS_BEARISH)
   {
      return (
         ob.high +
         buffer
      );
   }

   return 0.0;
}


//+------------------------------------------------------------------+
//| Calculate entry price                                            |
//+------------------------------------------------------------------+

double CalculateEntryPrice(
   OrderBlockState &ob,
   double rejectionHigh,
   double rejectionLow
)
{
   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID
      );

   double ask =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_ASK
      );


   if(ob.direction == BIAS_BULLISH)
   {
      if(ask > 0.0)
         return ask;

      return rejectionHigh;
   }


   if(ob.direction == BIAS_BEARISH)
   {
      if(bid > 0.0)
         return bid;

      return rejectionLow;
   }

   return 0.0;
}


//+------------------------------------------------------------------+
//| Calculate take profit                                            |
//+------------------------------------------------------------------+

double CalculateEntryTakeProfit(
   ENUM_BIAS direction,
   double entry,
   double stopLoss
)
{
   if(entry <= 0.0 ||
      stopLoss <= 0.0)
   {
      return 0.0;
   }

   double risk =
      MathAbs(
         entry - stopLoss
      );

   if(risk <= 0.0)
      return 0.0;


   if(direction == BIAS_BULLISH)
   {
      return (
         entry +
         risk * InpEntryRiskReward
      );
   }


   if(direction == BIAS_BEARISH)
   {
      return (
         entry -
         risk * InpEntryRiskReward
      );
   }

   return 0.0;
}


//+------------------------------------------------------------------+
//| Validate entry zone                                              |
//+------------------------------------------------------------------+

bool ValidateEntryZone(
   OrderBlockState &ob,
   EntryConfirmationState &result
)
{
   result.valid = false;

   if(!ob.valid)
      return false;

   //===============================================================
   // OB MUST STILL BE VALID
   //===============================================================

   if(!ob.fresh)
      return false;

   if(!ob.unmitigated)
      return false;

   if(!ob.hasFVG)
      return false;

   if(!ob.fvgNearOB)
      return false;


   //===============================================================
   // CURRENT PRICE
   //===============================================================

   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID
      );

   double ask =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_ASK
      );

   double currentPrice =
      (bid + ask) * 0.5;

   if(currentPrice <= 0.0)
      return false;


   //===============================================================
   // PRICE MUST HAVE RETURNED TO OB
   //===============================================================

   bool priceInside =
      IsPriceInsideOrderBlock(
         currentPrice,
         ob.high,
         ob.low
      );

   bool m5Touched =
      CandleTouchesOrderBlock(
         PERIOD_M5,
         1,
         ob.high,
         ob.low
      );


   if(!priceInside &&
      !m5Touched)
   {
      return false;
   }


   result.priceInsideOB =
      priceInside;

   result.m5TouchedOB =
      m5Touched;


   //===============================================================
   // M5 REJECTION
   //===============================================================

   double m5High = 0.0;
   double m5Low = 0.0;
   double m5Wick = 0.0;
   double m5Body = 0.0;

   datetime m5Time = 0;

   bool m5Rejected = false;

   if(InpUseM5EntryConfirmation)
   {
      m5Rejected =
         FindM5Rejection(
            ob,
            m5High,
            m5Low,
            m5Wick,
            m5Body,
            m5Time
         );
   }


   //===============================================================
   // M1 REJECTION
   //
   // Optional.
   //
   // M1 confirmation can confirm the entry,
   // but M1 is NOT required if M5 rejection is valid.
   //===============================================================

   double m1High = 0.0;
   double m1Low = 0.0;
   double m1Wick = 0.0;
   double m1Body = 0.0;

   datetime m1Time = 0;

   bool m1Rejected = false;

   if(InpUseM1EntryConfirmation)
   {
      m1Rejected =
         FindM1Rejection(
            ob,
            m1High,
            m1Low,
            m1Wick,
            m1Body,
            m1Time
         );
   }


   //===============================================================
   // ENTRY CONFIRMATION
   //
   // M5 OR M1 is sufficient.
   //===============================================================

   if(!m5Rejected &&
      !m1Rejected)
   {
      return false;
   }


   result.m5StrongRejection =
      m5Rejected;

   result.m1StrongRejection =
      m1Rejected;

   result.m5Confirmation =
      m5Rejected;

   result.m1Confirmation =
      m1Rejected;

   result.zoneHeld =
      true;

   result.direction =
      ob.direction;


   //===============================================================
   // Select rejection candle information
   //===============================================================

   if(m5Rejected)
   {
      result.rejectionHigh =
         m5High;

      result.rejectionLow =
         m5Low;

      result.rejectionWick =
         m5Wick;

      result.rejectionBody =
         m5Body;

      result.confirmationTime =
         m5Time;
   }
   else
   {
      result.rejectionHigh =
         m1High;

      result.rejectionLow =
         m1Low;

      result.rejectionWick =
         m1Wick;

      result.rejectionBody =
         m1Body;

      result.confirmationTime =
         m1Time;
   }


   //===============================================================
   // ENTRY
   //===============================================================

   result.entryPrice =
      CalculateEntryPrice(
         ob,
         result.rejectionHigh,
         result.rejectionLow
      );

   if(result.entryPrice <= 0.0)
      return false;


   //===============================================================
   // STOP LOSS
   //===============================================================

   result.stopLoss =
      CalculateEntryStopLoss(
         ob
      );

   if(result.stopLoss <= 0.0)
      return false;


   //===============================================================
   // STOP BUFFER
   //===============================================================

   double atr =
      GetEntryATR(
         PERIOD_M5
      );

   if(atr <= 0.0)
      return false;

   result.stopBuffer =
      atr *
      InpEntryStopBufferATR;


   //===============================================================
   // TAKE PROFIT
   //===============================================================

   result.takeProfit =
      CalculateEntryTakeProfit(
         result.direction,
         result.entryPrice,
         result.stopLoss
      );

   if(result.takeProfit <= 0.0)
      return false;


   //===============================================================
   // OB INFORMATION
   //===============================================================

   result.obHigh =
      ob.high;

   result.obLow =
      ob.low;


   //===============================================================
   // SCORE
   //===============================================================

   result.score = 0;

   // Price returned to OB
   result.score += 30;

   // M5 rejection
   if(m5Rejected)
      result.score += 35;

   // M1 rejection is additional confirmation
   if(m1Rejected)
      result.score += 20;

   // Zone held
   if(result.zoneHeld)
      result.score += 15;

   if(result.score > 100)
      result.score = 100;


   //===============================================================
   // VALID ENTRY
   //===============================================================

   result.valid = true;

   return true;
}


//+------------------------------------------------------------------+
//| Main Entry Scan                                                  |
//+------------------------------------------------------------------+

void ScanEntryConfirmation(
   OrderBlockState &ob,
   EntryConfirmationState &result
)
{
   ZeroMemory(result);

   result.valid = false;

   if(!ob.valid)
      return;

   ValidateEntryZone(
      ob,
      result
   );

   g_Entry =
      result;
}


//+------------------------------------------------------------------+

#endif
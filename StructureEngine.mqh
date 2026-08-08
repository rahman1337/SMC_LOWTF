#ifndef SCALPINGEA_M5_STRUCTURE_ENGINE_MQH
#define SCALPINGEA_M5_STRUCTURE_ENGINE_MQH

#include "Constants.mqh"
#include "Structures.mqh"

//+------------------------------------------------------------------+
//| Global Structure State                                           |
//+------------------------------------------------------------------+
StructureConfirmationState g_Structure;

//+------------------------------------------------------------------+
//| Settings                                                          |
//+------------------------------------------------------------------+
input group "=== M5 Structure Confirmation ==="

input int    InpStructureLookback       = 3;
input int    InpStructureSearchBars     = 60;
input double InpMinimumDisplacementATR  = 0.50;
input double InpMinimumBreakATR         = 0.05;
input double InpIFVGMinimumGapATR       = 0.03;
input int    InpMaxConfirmationBars     = 4;

//+------------------------------------------------------------------+
//| M5 Swing                                                          |
//+------------------------------------------------------------------+
struct M5Swing
{
   bool valid;

   double price;

   int shift;

   datetime time;
};

//+------------------------------------------------------------------+
//| Reset                                                             |
//+------------------------------------------------------------------+
void ResetStructureState()
{
   ZeroMemory(g_Structure);
}

//+------------------------------------------------------------------+
//| ATR                                                               |
//+------------------------------------------------------------------+
double GetStructureATR()
{
   int handle =
      iATR(
         _Symbol,
         PERIOD_M5,
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
//| Find M5 Swing High                                               |
//+------------------------------------------------------------------+
bool FindM5SwingHigh(
   int startShift,
   M5Swing &swing
)
{
   ZeroMemory(swing);

   int bars =
      Bars(
         _Symbol,
         PERIOD_M5
      );

   if(bars <=
      InpStructureLookback * 2 + 5)
   {
      return false;
   }

   int maxShift =
      MathMin(
         InpStructureSearchBars,
         bars - InpStructureLookback - 1
      );

   if(startShift < InpStructureLookback + 1)
      startShift = InpStructureLookback + 1;

   for(int shift = startShift;
       shift <= maxShift;
       shift++)
   {
      double high =
         iHigh(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(high <= 0.0)
         continue;

      bool valid = true;

      for(int i = 1;
          i <= InpStructureLookback;
          i++)
      {
         double leftHigh =
            iHigh(
               _Symbol,
               PERIOD_M5,
               shift - i
            );

         double rightHigh =
            iHigh(
               _Symbol,
               PERIOD_M5,
               shift + i
            );

         if(high <= leftHigh ||
            high <= rightHigh)
         {
            valid = false;
            break;
         }
      }

      if(!valid)
         continue;

      swing.valid = true;
      swing.price = high;
      swing.shift = shift;

      swing.time =
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
//| Find M5 Swing Low                                                |
//+------------------------------------------------------------------+
bool FindM5SwingLow(
   int startShift,
   M5Swing &swing
)
{
   ZeroMemory(swing);

   int bars =
      Bars(
         _Symbol,
         PERIOD_M5
      );

   if(bars <=
      InpStructureLookback * 2 + 5)
   {
      return false;
   }

   int maxShift =
      MathMin(
         InpStructureSearchBars,
         bars - InpStructureLookback - 1
      );

   if(startShift < InpStructureLookback + 1)
      startShift = InpStructureLookback + 1;

   for(int shift = startShift;
       shift <= maxShift;
       shift++)
   {
      double low =
         iLow(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(low <= 0.0)
         continue;

      bool valid = true;

      for(int i = 1;
          i <= InpStructureLookback;
          i++)
      {
         double leftLow =
            iLow(
               _Symbol,
               PERIOD_M5,
               shift - i
            );

         double rightLow =
            iLow(
               _Symbol,
               PERIOD_M5,
               shift + i
            );

         if(low >= leftLow ||
            low >= rightLow)
         {
            valid = false;
            break;
         }
      }

      if(!valid)
         continue;

      swing.valid = true;
      swing.price = low;
      swing.shift = shift;

      swing.time =
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
//| Strong Displacement                                              |
//+------------------------------------------------------------------+
bool IsStrongDisplacement(
   int shift,
   ENUM_BIAS direction,
   double &displacementATR
)
{
   displacementATR = 0.0;

   if(shift < 1)
      return false;

   double open =
      iOpen(
         _Symbol,
         PERIOD_M5,
         shift
      );

   double close =
      iClose(
         _Symbol,
         PERIOD_M5,
         shift
      );

   double high =
      iHigh(
         _Symbol,
         PERIOD_M5,
         shift
      );

   double low =
      iLow(
         _Symbol,
         PERIOD_M5,
         shift
      );

   double range = high - low;

   if(range <= 0.0)
      return false;

   double body =
      MathAbs(
         close - open
      );

   double atr =
      GetStructureATR();

   if(atr <= 0.0)
      return false;

   displacementATR =
      body / atr;

   if(displacementATR <
      InpMinimumDisplacementATR)
   {
      return false;
   }

   if(direction == BIAS_BULLISH)
   {
      if(close <= open)
         return false;
   }
   else
   if(direction == BIAS_BEARISH)
   {
      if(close >= open)
         return false;
   }
   else
   {
      return false;
   }

   if(body / range < 0.50)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Bullish break AFTER sweep                                        |
//+------------------------------------------------------------------+
bool DetectBullishBreakAfterSweep(
   double level,
   datetime sweepTime,
   int maxBars,
   double &breakPrice,
   int &breakShift
)
{
   breakPrice = 0.0;
   breakShift = -1;

   double atr =
      GetStructureATR();

   if(atr <= 0.0)
      return false;

   double minimumBreak =
      atr * InpMinimumBreakATR;

   int bars =
      Bars(
         _Symbol,
         PERIOD_M5
      );

   int limit =
      MathMin(
         maxBars,
         bars - 1
      );

   // Search from the sweep toward the present.
   for(int shift = limit;
       shift >= 1;
       shift--)
   {
      datetime candleTime =
         iTime(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(candleTime <= sweepTime)
         continue;

      double close =
         iClose(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(close >
         level + minimumBreak)
      {
         breakPrice = close;
         breakShift = shift;

         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Bearish break AFTER sweep                                        |
//+------------------------------------------------------------------+
bool DetectBearishBreakAfterSweep(
   double level,
   datetime sweepTime,
   int maxBars,
   double &breakPrice,
   int &breakShift
)
{
   breakPrice = 0.0;
   breakShift = -1;

   double atr =
      GetStructureATR();

   if(atr <= 0.0)
      return false;

   double minimumBreak =
      atr * InpMinimumBreakATR;

   int bars =
      Bars(
         _Symbol,
         PERIOD_M5
      );

   int limit =
      MathMin(
         maxBars,
         bars - 1
      );

   for(int shift = limit;
       shift >= 1;
       shift--)
   {
      datetime candleTime =
         iTime(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(candleTime <= sweepTime)
         continue;

      double close =
         iClose(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(close <
         level - minimumBreak)
      {
         breakPrice = close;
         breakShift = shift;

         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Bullish iFVG                                                      |
//+------------------------------------------------------------------+
bool DetectBullishIFVG(
   int referenceShift
)
{
   if(referenceShift < 2)
      return false;

   double atr =
      GetStructureATR();

   if(atr <= 0.0)
      return false;

   int middle = referenceShift;
   int older  = middle + 1;
   int newer  = middle - 1;

   double olderHigh =
      iHigh(
         _Symbol,
         PERIOD_M5,
         older
      );

   double newerLow =
      iLow(
         _Symbol,
         PERIOD_M5,
         newer
      );

   if(olderHigh <= 0.0 ||
      newerLow <= 0.0)
   {
      return false;
   }

   if(newerLow <= olderHigh)
      return false;

   double gap =
      newerLow - olderHigh;

   if(gap <
      atr * InpIFVGMinimumGapATR)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Bearish iFVG                                                      |
//+------------------------------------------------------------------+
bool DetectBearishIFVG(
   int referenceShift
)
{
   if(referenceShift < 2)
      return false;

   double atr =
      GetStructureATR();

   if(atr <= 0.0)
      return false;

   int middle = referenceShift;
   int older  = middle + 1;
   int newer  = middle - 1;

   double olderLow =
      iLow(
         _Symbol,
         PERIOD_M5,
         older
      );

   double newerHigh =
      iHigh(
         _Symbol,
         PERIOD_M5,
         newer
      );

   if(olderLow <= 0.0 ||
      newerHigh <= 0.0)
   {
      return false;
   }

   if(newerHigh >= olderLow)
      return false;

   double gap =
      olderLow - newerHigh;

   if(gap <
      atr * InpIFVGMinimumGapATR)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Confirm Bullish Structure                                        |
//+------------------------------------------------------------------+
bool ConfirmBullishStructure(
   LiquiditySweepState &sweep,
   StructureConfirmationState &result
)
{
   ZeroMemory(result);

   result.valid = false;

   if(!sweep.valid)
      return false;

   if(sweep.direction != BIAS_BULLISH)
      return false;

   if(sweep.sweepTime <= 0)
      return false;

   int sweepShift = iBarShift(
      _Symbol,
      PERIOD_M5,
      sweep.sweepTime,
      false
   );

   if(sweepShift < 1)
      return false;

   M5Swing swingHigh;

   if(!FindM5SwingHigh(
         sweepShift + InpStructureLookback,
         swingHigh
      ))
   {
      return false;
   }

   if(swingHigh.price <=
      sweep.liquidityPrice)
   {
      return false;
   }

   double breakPrice = 0.0;
   int breakShift = -1;

   if(!DetectBullishBreakAfterSweep(
         swingHigh.price,
         sweep.sweepTime,
         InpMaxConfirmationBars,
         breakPrice,
         breakShift
      ))
   {
      return false;
   }

   double displacementATR = 0.0;

   if(!IsStrongDisplacement(
         breakShift,
         BIAS_BULLISH,
         displacementATR
      ))
   {
      return false;
   }

   bool ifvg =
      DetectBullishIFVG(
         breakShift
      );

   result.valid = true;

   result.direction = BIAS_BULLISH;

   result.sweepTime =
      sweep.sweepTime;

   result.sweepShift =
      sweepShift;

   result.structureBreak = true;

   result.bos = true;
   result.mss = true;
   result.choch = true;

   result.ifvg = ifvg;

   result.displacement = true;
   result.confirmationCandle = true;

   result.brokenSwing =
      swingHigh.price;

   result.breakPrice =
      breakPrice;

   result.displacementSize =
      MathAbs(
         iClose(
            _Symbol,
            PERIOD_M5,
            breakShift
         )
         -
         iOpen(
            _Symbol,
            PERIOD_M5,
            breakShift
         )
      );

   result.displacementATR =
      displacementATR;

   result.confirmationTime =
      iTime(
         _Symbol,
         PERIOD_M5,
         breakShift
      );

   result.timeframe = PERIOD_M5;

   result.score = 0;

   result.score += 30;
   result.score += 20;
   result.score += 15;
   result.score += 15;

   if(ifvg)
      result.score += 20;

   if(result.score > 100)
      result.score = 100;

   return true;
}

//+------------------------------------------------------------------+
//| Confirm Bearish Structure                                        |
//+------------------------------------------------------------------+
bool ConfirmBearishStructure(
   LiquiditySweepState &sweep,
   StructureConfirmationState &result
)
{
   ZeroMemory(result);

   result.valid = false;

   if(!sweep.valid)
      return false;

   if(sweep.direction != BIAS_BEARISH)
      return false;

   if(sweep.sweepTime <= 0)
      return false;

   int sweepShift = iBarShift(
      _Symbol,
      PERIOD_M5,
      sweep.sweepTime,
      false
   );

   if(sweepShift < 1)
      return false;

   M5Swing swingLow;

   if(!FindM5SwingLow(
         sweepShift + InpStructureLookback,
         swingLow
      ))
   {
      return false;
   }

   if(swingLow.price >=
      sweep.liquidityPrice)
   {
      return false;
   }

   double breakPrice = 0.0;
   int breakShift = -1;

   if(!DetectBearishBreakAfterSweep(
         swingLow.price,
         sweep.sweepTime,
         InpMaxConfirmationBars,
         breakPrice,
         breakShift
      ))
   {
      return false;
   }

   double displacementATR = 0.0;

   if(!IsStrongDisplacement(
         breakShift,
         BIAS_BEARISH,
         displacementATR
      ))
   {
      return false;
   }

   bool ifvg =
      DetectBearishIFVG(
         breakShift
      );

   result.valid = true;

   result.direction = BIAS_BEARISH;

   result.sweepTime =
      sweep.sweepTime;

   result.sweepShift =
      sweepShift;

   result.structureBreak = true;

   result.bos = true;
   result.mss = true;
   result.choch = true;

   result.ifvg = ifvg;

   result.displacement = true;
   result.confirmationCandle = true;

   result.brokenSwing =
      swingLow.price;

   result.breakPrice =
      breakPrice;

   result.displacementSize =
      MathAbs(
         iClose(
            _Symbol,
            PERIOD_M5,
            breakShift
         )
         -
         iOpen(
            _Symbol,
            PERIOD_M5,
            breakShift
         )
      );

   result.displacementATR =
      displacementATR;

   result.confirmationTime =
      iTime(
         _Symbol,
         PERIOD_M5,
         breakShift
      );

   result.timeframe = PERIOD_M5;

   result.score = 0;

   result.score += 30;
   result.score += 20;
   result.score += 15;
   result.score += 15;

   if(ifvg)
      result.score += 20;

   if(result.score > 100)
      result.score = 100;

   return true;
}

//+------------------------------------------------------------------+
//| Main M5 Structure Scan                                           |
//+------------------------------------------------------------------+
void ScanM5Structure(
   ENUM_BIAS allowedDirection,
   LiquiditySweepState &sweep,
   StructureConfirmationState &result
)
{
   ZeroMemory(result);

   if(!sweep.valid)
      return;

   if(allowedDirection !=
      sweep.direction)
   {
      return;
   }

   if(allowedDirection == BIAS_BULLISH)
   {
      ConfirmBullishStructure(
         sweep,
         result
      );

      return;
   }

   if(allowedDirection == BIAS_BEARISH)
   {
      ConfirmBearishStructure(
         sweep,
         result
      );

      return;
   }
}

//+------------------------------------------------------------------+
//| Convenience                                                      |
//+------------------------------------------------------------------+
bool ConfirmM5Structure()
{
   ZeroMemory(g_Structure);

   if(!g_Liquidity.valid)
      return false;

   ScanM5Structure(
      g_Liquidity.direction,
      g_Liquidity,
      g_Structure
   );

   return g_Structure.valid;
}

//+------------------------------------------------------------------+

#endif
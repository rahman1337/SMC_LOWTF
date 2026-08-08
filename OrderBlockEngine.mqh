#ifndef SCALPINGEA_ORDER_BLOCK_ENGINE_MQH
#define SCALPINGEA_ORDER_BLOCK_ENGINE_MQH

#include "Constants.mqh"
#include "Structures.mqh"

//+------------------------------------------------------------------+
//| Global OB State                                                  |
//+------------------------------------------------------------------+
OrderBlockState g_OrderBlock;

//+------------------------------------------------------------------+
//| Settings                                                         |
//+------------------------------------------------------------------+
input group "=== M5 / M1 ORDER BLOCK + FVG ==="

input int    InpOBLookback             = 3;
input int    InpOBSearchBars           = 100;
input int    InpOBDisplacementBars     = 8;

input double InpOBMinimumBodyATR       = 0.20;
input double InpOBMaximumSizeATR       = 2.50;

input double InpFVGMinimumSizeATR      = 0.03;
input double InpFVGMaximumDistanceATR  = 0.50;

input int    InpOBMaximumAge           = 80;

input bool   InpRequireOBFVG            = true;
input bool   InpAllowM1OrderBlock       = true;


//+------------------------------------------------------------------+
//| ATR                                                              |
//+------------------------------------------------------------------+
double GetOBATR(
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
//| Candle direction                                                 |
//+------------------------------------------------------------------+
bool IsBullishOBCandle(
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return
      iClose(
         _Symbol,
         timeframe,
         shift
      )
      >
      iOpen(
         _Symbol,
         timeframe,
         shift
      );
}


//+------------------------------------------------------------------+
bool IsBearishOBCandle(
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return
      iClose(
         _Symbol,
         timeframe,
         shift
      )
      <
      iOpen(
         _Symbol,
         timeframe,
         shift
      );
}


//+------------------------------------------------------------------+
//| Body                                                             |
//+------------------------------------------------------------------+
double GetOBBody(
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return
      MathAbs(
         iClose(
            _Symbol,
            timeframe,
            shift
         )
         -
         iOpen(
            _Symbol,
            timeframe,
            shift
         )
      );
}


//+------------------------------------------------------------------+
//| Range                                                            |
//+------------------------------------------------------------------+
double GetOBRange(
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   return
      iHigh(
         _Symbol,
         timeframe,
         shift
      )
      -
      iLow(
         _Symbol,
         timeframe,
         shift
      );
}


//+------------------------------------------------------------------+
//| Bullish FVG                                                      |
//+------------------------------------------------------------------+
bool FindBullishOBFVG(
   ENUM_TIMEFRAMES timeframe,
   int middleShift,
   double &fvgHigh,
   double &fvgLow
)
{
   fvgHigh = 0.0;
   fvgLow  = 0.0;

   int olderShift = middleShift + 1;
   int newerShift = middleShift - 1;

   if(newerShift < 1)
      return false;

   double olderHigh =
      iHigh(
         _Symbol,
         timeframe,
         olderShift
      );

   double newerLow =
      iLow(
         _Symbol,
         timeframe,
         newerShift
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

   double atr =
      GetOBATR(timeframe);

   if(atr <= 0.0)
      return false;

   if(gap <
      atr * InpFVGMinimumSizeATR)
   {
      return false;
   }

   fvgHigh = newerLow;
   fvgLow  = olderHigh;

   return true;
}


//+------------------------------------------------------------------+
//| Bearish FVG                                                      |
//+------------------------------------------------------------------+
bool FindBearishOBFVG(
   ENUM_TIMEFRAMES timeframe,
   int middleShift,
   double &fvgHigh,
   double &fvgLow
)
{
   fvgHigh = 0.0;
   fvgLow  = 0.0;

   int olderShift = middleShift + 1;
   int newerShift = middleShift - 1;

   if(newerShift < 1)
      return false;

   double olderLow =
      iLow(
         _Symbol,
         timeframe,
         olderShift
      );

   double newerHigh =
      iHigh(
         _Symbol,
         timeframe,
         newerShift
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

   double atr =
      GetOBATR(timeframe);

   if(atr <= 0.0)
      return false;

   if(gap <
      atr * InpFVGMinimumSizeATR)
   {
      return false;
   }

   fvgHigh = olderLow;
   fvgLow  = newerHigh;

   return true;
}


//+------------------------------------------------------------------+
//| FVG overlaps OB                                                  |
//+------------------------------------------------------------------+
bool DoesFVGOverlapOB(
   double fvgHigh,
   double fvgLow,
   double obHigh,
   double obLow
)
{
   if(fvgHigh < obLow)
      return false;

   if(fvgLow > obHigh)
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| FVG distance                                                     |
//+------------------------------------------------------------------+
double GetOBFVGDistance(
   double fvgHigh,
   double fvgLow,
   double obHigh,
   double obLow
)
{
   if(fvgHigh < obLow)
      return obLow - fvgHigh;

   if(fvgLow > obHigh)
      return fvgLow - obHigh;

   return 0.0;
}


//+------------------------------------------------------------------+
//| Validate OB/FVG relationship                                     |
//+------------------------------------------------------------------+
bool ValidateOBFVGRelationship(
   ENUM_TIMEFRAMES timeframe,
   double fvgHigh,
   double fvgLow,
   double obHigh,
   double obLow,
   bool &inside,
   bool &beside,
   bool &near,
   double &distance
)
{
   inside   = false;
   beside   = false;
   near     = false;
   distance = 0.0;

   double atr =
      GetOBATR(timeframe);

   if(atr <= 0.0)
      return false;

   if(DoesFVGOverlapOB(
         fvgHigh,
         fvgLow,
         obHigh,
         obLow
      ))
   {
      inside   = true;
      near     = true;
      distance = 0.0;

      return true;
   }

   distance =
      GetOBFVGDistance(
         fvgHigh,
         fvgLow,
         obHigh,
         obLow
      );

   if(distance <=
      atr * InpFVGMaximumDistanceATR)
   {
      beside = true;
      near   = true;

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| OB mitigation                                                    |
//+------------------------------------------------------------------+
bool IsOrderBlockMitigatedTF(
   ENUM_TIMEFRAMES timeframe,
   ENUM_BIAS direction,
   double obHigh,
   double obLow,
   int obShift
)
{
   if(obShift <= 1)
      return false;

   for(int shift = obShift - 1;
       shift >= 1;
       shift--)
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

      if(direction == BIAS_BULLISH)
      {
         if(low < obLow)
            return true;
      }
      else
      if(direction == BIAS_BEARISH)
      {
         if(high > obHigh)
            return true;
      }
   }

   return false;
}


//+------------------------------------------------------------------+
//| Freshness                                                        |
//+------------------------------------------------------------------+
bool IsOrderBlockFreshTF(
   int shift
)
{
   if(shift <= 1)
      return false;

   if(shift >
      InpOBMaximumAge)
   {
      return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//| OB must be AFTER liquidity sweep                                 |
//+------------------------------------------------------------------+
bool IsOBAfterLiquiditySweep(
   ENUM_TIMEFRAMES timeframe,
   int obShift,
   LiquiditySweepState &sweep
)
{
   if(!sweep.valid)
      return false;

   if(sweep.sweepTime <= 0)
      return false;

   datetime obTime =
      iTime(
         _Symbol,
         timeframe,
         obShift
      );

   if(obTime <= 0)
      return false;

   /*
      OB must be created AFTER the liquidity sweep.

      Market series:
         larger shift = older candle
         smaller shift = newer candle

      Therefore:
         OB time > sweep time
   */

   if(obTime <= sweep.sweepTime)
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| OB must be BEFORE confirmation                                   |
//+------------------------------------------------------------------+
bool IsOBBeforeConfirmation(
   ENUM_TIMEFRAMES timeframe,
   int obShift,
   StructureConfirmationState &structure
)
{
   if(!structure.valid)
      return false;

   if(structure.confirmationTime <= 0)
      return false;

   datetime obTime =
      iTime(
         _Symbol,
         timeframe,
         obShift
      );

   if(obTime <= 0)
      return false;

   /*
      OB must exist BEFORE the confirmation candle.

      Therefore:
         OB time < confirmation time
   */

   if(obTime >= structure.confirmationTime)
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| OB chronological validation                                     |
//+------------------------------------------------------------------+
bool IsOBChronologicallyValid(
   ENUM_TIMEFRAMES timeframe,
   int obShift,
   LiquiditySweepState &sweep,
   StructureConfirmationState &structure
)
{
   if(!sweep.valid)
      return false;

   if(!structure.valid)
      return false;

   if(!IsOBAfterLiquiditySweep(
         timeframe,
         obShift,
         sweep
      ))
   {
      return false;
   }

   if(!IsOBBeforeConfirmation(
         timeframe,
         obShift,
         structure
      ))
   {
      return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//| OB aligned with M5 confirmation                                  |
//+------------------------------------------------------------------+
bool IsOBAlignedWithM5Confirmation(
   ENUM_TIMEFRAMES timeframe,
   ENUM_BIAS direction,
   int obShift,
   StructureConfirmationState &structure
)
{
   if(!structure.valid)
      return false;

   if(structure.direction != direction)
      return false;

   if(structure.confirmationTime <= 0)
      return false;

   datetime obTime =
      iTime(
         _Symbol,
         timeframe,
         obShift
      );

   if(obTime <= 0)
      return false;

   /*
      OB must be created BEFORE confirmation.
   */

   if(obTime >=
      structure.confirmationTime)
   {
      return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//| Find OB search limits                                            |
//+------------------------------------------------------------------+
void GetOBSearchWindow(
   ENUM_TIMEFRAMES timeframe,
   LiquiditySweepState &sweep,
   StructureConfirmationState &structure,
   int &startShift,
   int &endShift
)
{
   startShift = 2;
   endShift   = InpOBSearchBars;

   if(!sweep.valid)
      return;

   if(!structure.valid)
      return;

   if(sweep.sweepTime <= 0)
      return;

   if(structure.confirmationTime <= 0)
      return;


   int sweepShift =
      iBarShift(
         _Symbol,
         timeframe,
         sweep.sweepTime,
         false
      );

   int confirmationShift =
      iBarShift(
         _Symbol,
         timeframe,
         structure.confirmationTime,
         false
      );


   /*
      We need an OB between:

         SWEEP
            ↓
         OB
            ↓
         DISPLACEMENT
            ↓
         CONFIRMATION

      In series indexing:

         sweepShift > obShift > confirmationShift
   */

   if(sweepShift < 1)
      return;

   if(confirmationShift < 1)
      confirmationShift = 1;


   /*
      The OB must be newer than the sweep.
   */

   startShift =
      MathMax(
         confirmationShift + 1,
         2
      );


   /*
      The OB must be older than the confirmation
      but newer than the sweep.

      Therefore the oldest allowed OB is just
      after the sweep in chronological order.
   */

   endShift =
      MathMin(
         sweepShift - 1,
         startShift + InpOBMaximumAge
      );


   /*
      Respect the global search limit.
   */

   endShift =
      MathMin(
         endShift,
         InpOBSearchBars
      );
}


//+------------------------------------------------------------------+
//| Validate displacement AFTER OB                                   |
//+------------------------------------------------------------------+
bool FindOBDisplacementAfterOB(
   ENUM_TIMEFRAMES timeframe,
   ENUM_BIAS direction,
   int obShift,
   int confirmationShift,
   int &displacementShift,
   double &displacementBody,
   double &displacementATR
)
{
   displacementShift = -1;
   displacementBody  = 0.0;
   displacementATR   = 0.0;

   if(obShift <= 1)
      return false;

   if(confirmationShift < 1)
      return false;

   /*
      The displacement MUST be newer than the OB
      and MUST occur before the confirmation candle.

      Series indexing:

         OB             = larger shift
         displacement  = smaller shift
         confirmation  = even smaller shift

      Therefore:

         obShift > displacementShift > confirmationShift
   */

   if(obShift <= confirmationShift + 1)
      return false;


   double atr =
      GetOBATR(timeframe);

   if(atr <= 0.0)
      return false;


   int firstShift =
      obShift - 1;

   int lastShift =
      confirmationShift + 1;


   for(int shift = firstShift;
       shift >= lastShift;
       shift--)
   {
      double open =
         iOpen(
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

      double range =
         high - low;

      if(range <= 0.0)
         continue;


      double body =
         MathAbs(
            close - open
         );


      if(body <
         atr * InpOBMinimumBodyATR)
      {
         continue;
      }


      /*
         Directional displacement.
      */

      if(direction == BIAS_BULLISH)
      {
         if(close <= open)
            continue;
      }
      else
      if(direction == BIAS_BEARISH)
      {
         if(close >= open)
            continue;
      }
      else
      {
         continue;
      }


      /*
         Require meaningful body participation.
      */

      if(body / range < 0.50)
         continue;


      displacementShift = shift;
      displacementBody  = body;
      displacementATR   = body / atr;

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Find bullish OB                                                  |
//+------------------------------------------------------------------+
bool FindBullishOBTF(
   ENUM_TIMEFRAMES timeframe,
   LiquiditySweepState &sweep,
   StructureConfirmationState &structure,
   OrderBlockState &result
)
{
   ZeroMemory(result);

   result.valid = false;

   if(!sweep.valid)
      return false;

   if(!structure.valid)
      return false;

   if(sweep.direction != BIAS_BULLISH)
      return false;

   if(structure.direction != BIAS_BULLISH)
      return false;


   double atr =
      GetOBATR(timeframe);

   if(atr <= 0.0)
      return false;


   int startShift;
   int endShift;


   GetOBSearchWindow(
      timeframe,
      sweep,
      structure,
      startShift,
      endShift
   );


   if(endShift < startShift)
      return false;


   int confirmationShift =
      iBarShift(
         _Symbol,
         timeframe,
         structure.confirmationTime,
         false
      );

   if(confirmationShift < 1)
      return false;


   /*
      Search candidate OBs from newest to oldest.
      Every candidate is forced into the chronological
      sweep -> OB -> displacement -> confirmation chain.
   */

   for(int shift = startShift;
       shift <= endShift;
       shift++)
   {
      /*
         Bullish OB = final bearish candle before
         bullish displacement.
      */

      if(!IsBearishOBCandle(
            timeframe,
            shift
         ))
      {
         continue;
      }


      /*
         HARD chronological rule:

         Sweep
           ↓
         OB
           ↓
         Confirmation

         Candidate OB must be after sweep and before
         confirmation.
      */

      if(!IsOBChronologicallyValid(
            timeframe,
            shift,
            sweep,
            structure
         ))
      {
         continue;
      }


      double obHigh =
         iHigh(
            _Symbol,
            timeframe,
            shift
         );

      double obLow =
         iLow(
            _Symbol,
            timeframe,
            shift
         );

      double obRange =
         obHigh - obLow;

      if(obRange <= 0.0)
         continue;


      if(obRange >
         atr * InpOBMaximumSizeATR)
      {
         continue;
      }


      if(!IsOrderBlockFreshTF(
            shift
         ))
      {
         continue;
      }


      if(IsOrderBlockMitigatedTF(
            timeframe,
            BIAS_BULLISH,
            obHigh,
            obLow,
            shift
         ))
      {
         continue;
      }


      if(!IsOBAlignedWithM5Confirmation(
            timeframe,
            BIAS_BULLISH,
            shift,
            structure
         ))
      {
         continue;
      }


      /*
         -----------------------------------------------------------
         DISPLACEMENT
         -----------------------------------------------------------

         The displacement MUST originate AFTER this OB.

         It must also happen BEFORE the confirmation candle.

         This is the key protection against selecting an unrelated
         old OB.
      */

      int displacementShift = -1;

      double displacementBody = 0.0;
      double displacementATR  = 0.0;


      if(!FindOBDisplacementAfterOB(
            timeframe,
            BIAS_BULLISH,
            shift,
            confirmationShift,
            displacementShift,
            displacementBody,
            displacementATR
         ))
      {
         continue;
      }


      /*
         -----------------------------------------------------------
         FVG
         -----------------------------------------------------------
      */

      bool hasFVG = false;

      double fvgHigh = 0.0;
      double fvgLow  = 0.0;

      bool fvgInside = false;
      bool fvgBeside = false;
      bool fvgNear   = false;

      double fvgDistance = 0.0;


      /*
         Search FVGs around the actual displacement,
         rather than allowing an arbitrary FVG anywhere
         in the search window.
      */

      for(int f = 0;
          f <= 3;
          f++)
      {
         int fvgShift =
            displacementShift + f;

         if(fvgShift < 2)
            continue;

         /*
            Do not allow the FVG candidate to move backward
            before the OB.
         */

         if(fvgShift >= shift)
            continue;

         double candidateHigh = 0.0;
         double candidateLow  = 0.0;


         if(!FindBullishOBFVG(
               timeframe,
               fvgShift,
               candidateHigh,
               candidateLow
            ))
         {
            continue;
         }


         bool inside = false;
         bool beside = false;
         bool near   = false;

         double distance = 0.0;


         if(!ValidateOBFVGRelationship(
               timeframe,
               candidateHigh,
               candidateLow,
               obHigh,
               obLow,
               inside,
               beside,
               near,
               distance
            ))
         {
            continue;
         }


         hasFVG = true;

         fvgHigh = candidateHigh;
         fvgLow  = candidateLow;

         fvgInside = inside;
         fvgBeside = beside;
         fvgNear   = near;

         fvgDistance = distance;

         break;
      }


      if(InpRequireOBFVG &&
         !hasFVG)
      {
         continue;
      }


      /*
         -----------------------------------------------------------
         ACCEPT OB
         -----------------------------------------------------------
      */

      result.valid = true;

      result.fresh = true;
      result.unmitigated = true;

      result.type =
         OB_BULLISH;

      result.direction =
         BIAS_BULLISH;


      result.high =
         obHigh;

      result.low =
         obLow;

      result.range =
         obRange;


      result.shift =
         shift;


      result.createdTime =
         iTime(
            _Symbol,
            timeframe,
            shift
         );


      result.open =
         iOpen(
            _Symbol,
            timeframe,
            shift
         );

      result.close =
         iClose(
            _Symbol,
            timeframe,
            shift
         );


      /*
         Displacement information.
      */

      result.displacementOrigin = true;

      result.structureAligned = true;


      /*
         FVG information.
      */

      result.hasFVG =
         hasFVG;

      result.fvgHigh =
         fvgHigh;

      result.fvgLow =
         fvgLow;

      result.fvgRange =
         fvgHigh - fvgLow;

      result.fvgInsideOB =
         fvgInside;

      result.fvgBesideOB =
         fvgBeside;

      result.fvgNearOB =
         fvgNear;

      result.fvgDistance =
         fvgDistance;


      /*
         -----------------------------------------------------------
         SCORE
         -----------------------------------------------------------
      */

      result.score = 0.0;

      result.score += 20.0; // valid OB
      result.score += 20.0; // after sweep / before confirmation
      result.score += 20.0; // displacement after OB
      result.score += 15.0; // fresh + unmitigated

      if(hasFVG)
         result.score += 15.0;

      if(fvgInside)
         result.score += 5.0;

      if(displacementATR >= 0.75)
         result.score += 5.0;


      if(result.score > 100.0)
         result.score = 100.0;


      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Find bearish OB                                                  |
//+------------------------------------------------------------------+
bool FindBearishOBTF(
   ENUM_TIMEFRAMES timeframe,
   LiquiditySweepState &sweep,
   StructureConfirmationState &structure,
   OrderBlockState &result
)
{
   ZeroMemory(result);

   result.valid = false;

   if(!sweep.valid)
      return false;

   if(!structure.valid)
      return false;

   if(sweep.direction != BIAS_BEARISH)
      return false;

   if(structure.direction != BIAS_BEARISH)
      return false;


   double atr =
      GetOBATR(timeframe);

   if(atr <= 0.0)
      return false;


   int startShift;
   int endShift;


   GetOBSearchWindow(
      timeframe,
      sweep,
      structure,
      startShift,
      endShift
   );


   if(endShift < startShift)
      return false;


   int confirmationShift =
      iBarShift(
         _Symbol,
         timeframe,
         structure.confirmationTime,
         false
      );

   if(confirmationShift < 1)
      return false;


   /*
      Search candidate OBs from newest to oldest.
   */

   for(int shift = startShift;
       shift <= endShift;
       shift++)
   {
      /*
         Bearish OB = final bullish candle before
         bearish displacement.
      */

      if(!IsBullishOBCandle(
            timeframe,
            shift
         ))
      {
         continue;
      }


      /*
         HARD chronological rule:

         Sweep
           ↓
         OB
           ↓
         Displacement
           ↓
         Confirmation
      */

      if(!IsOBChronologicallyValid(
            timeframe,
            shift,
            sweep,
            structure
         ))
      {
         continue;
      }


      double obHigh =
         iHigh(
            _Symbol,
            timeframe,
            shift
         );

      double obLow =
         iLow(
            _Symbol,
            timeframe,
            shift
         );

      double obRange =
         obHigh - obLow;

      if(obRange <= 0.0)
         continue;


      if(obRange >
         atr * InpOBMaximumSizeATR)
      {
         continue;
      }


      if(!IsOrderBlockFreshTF(
            shift
         ))
      {
         continue;
      }


      if(IsOrderBlockMitigatedTF(
            timeframe,
            BIAS_BEARISH,
            obHigh,
            obLow,
            shift
         ))
      {
         continue;
      }


      if(!IsOBAlignedWithM5Confirmation(
            timeframe,
            BIAS_BEARISH,
            shift,
            structure
         ))
      {
         continue;
      }


      /*
         -----------------------------------------------------------
         DISPLACEMENT
         -----------------------------------------------------------
      */

      int displacementShift = -1;

      double displacementBody = 0.0;
      double displacementATR  = 0.0;


      if(!FindOBDisplacementAfterOB(
            timeframe,
            BIAS_BEARISH,
            shift,
            confirmationShift,
            displacementShift,
            displacementBody,
            displacementATR
         ))
      {
         continue;
      }


      /*
         -----------------------------------------------------------
         FVG
         -----------------------------------------------------------
      */

      bool hasFVG = false;

      double fvgHigh = 0.0;
      double fvgLow  = 0.0;

      bool fvgInside = false;
      bool fvgBeside = false;
      bool fvgNear   = false;

      double fvgDistance = 0.0;


      /*
         FVG must be related to the actual displacement,
         not some unrelated old FVG.
      */

      for(int f = 0;
          f <= 3;
          f++)
      {
         int fvgShift =
            displacementShift + f;

         if(fvgShift < 2)
            continue;

         if(fvgShift >= shift)
            continue;


         double candidateHigh = 0.0;
         double candidateLow  = 0.0;


         if(!FindBearishOBFVG(
               timeframe,
               fvgShift,
               candidateHigh,
               candidateLow
            ))
         {
            continue;
         }


         bool inside = false;
         bool beside = false;
         bool near   = false;

         double distance = 0.0;


         if(!ValidateOBFVGRelationship(
               timeframe,
               candidateHigh,
               candidateLow,
               obHigh,
               obLow,
               inside,
               beside,
               near,
               distance
            ))
         {
            continue;
         }


         hasFVG = true;

         fvgHigh = candidateHigh;
         fvgLow  = candidateLow;

         fvgInside = inside;
         fvgBeside = beside;
         fvgNear   = near;

         fvgDistance = distance;

         break;
      }


      if(InpRequireOBFVG &&
         !hasFVG)
      {
         continue;
      }


      /*
         -----------------------------------------------------------
         ACCEPT OB
         -----------------------------------------------------------
      */

      result.valid = true;

      result.fresh = true;
      result.unmitigated = true;

      result.type =
         OB_BEARISH;

      result.direction =
         BIAS_BEARISH;


      result.high =
         obHigh;

      result.low =
         obLow;

      result.range =
         obRange;


      result.shift =
         shift;


      result.createdTime =
         iTime(
            _Symbol,
            timeframe,
            shift
         );


      result.open =
         iOpen(
            _Symbol,
            timeframe,
            shift
         );

      result.close =
         iClose(
            _Symbol,
            timeframe,
            shift
         );


      /*
         Displacement information.
      */

      result.displacementOrigin = true;

      result.structureAligned = true;


      /*
         FVG information.
      */

      result.hasFVG =
         hasFVG;

      result.fvgHigh =
         fvgHigh;

      result.fvgLow =
         fvgLow;

      result.fvgRange =
         fvgHigh - fvgLow;

      result.fvgInsideOB =
         fvgInside;

      result.fvgBesideOB =
         fvgBeside;

      result.fvgNearOB =
         fvgNear;

      result.fvgDistance =
         fvgDistance;


      /*
         -----------------------------------------------------------
         SCORE
         -----------------------------------------------------------
      */

      result.score = 0.0;

      result.score += 20.0; // valid OB
      result.score += 20.0; // after sweep / before confirmation
      result.score += 20.0; // displacement after OB
      result.score += 15.0; // fresh + unmitigated

      if(hasFVG)
         result.score += 15.0;

      if(fvgInside)
         result.score += 5.0;

      if(displacementATR >= 0.75)
         result.score += 5.0;


      if(result.score > 100.0)
         result.score = 100.0;


      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Select strongest OB                                              |
//+------------------------------------------------------------------+
bool SelectBestOrderBlock(
   ENUM_BIAS direction,
   LiquiditySweepState &sweep,
   StructureConfirmationState &structure,
   OrderBlockState &result
)
{
   ZeroMemory(result);

   result.valid = false;


   OrderBlockState best;

   ZeroMemory(best);

   bool found = false;


   //===============================================================
   // M5
   //===============================================================

   OrderBlockState m5;

   ZeroMemory(m5);


   if(direction == BIAS_BULLISH)
   {
      if(FindBullishOBTF(
            PERIOD_M5,
            sweep,
            structure,
            m5
         ))
      {
         best = m5;
         found = true;
      }
   }
   else
   if(direction == BIAS_BEARISH)
   {
      if(FindBearishOBTF(
            PERIOD_M5,
            sweep,
            structure,
            m5
         ))
      {
         best = m5;
         found = true;
      }
   }


   //===============================================================
   // M1 refinement
   //===============================================================

   if(InpAllowM1OrderBlock)
   {
      OrderBlockState m1;

      ZeroMemory(m1);

      bool m1Found = false;


      if(direction == BIAS_BULLISH)
      {
         m1Found =
            FindBullishOBTF(
               PERIOD_M1,
               sweep,
               structure,
               m1
            );
      }
      else
      if(direction == BIAS_BEARISH)
      {
         m1Found =
            FindBearishOBTF(
               PERIOD_M1,
               sweep,
               structure,
               m1
            );
      }


      if(m1Found)
      {
         if(!found ||
            m1.score > best.score)
         {
            best = m1;
            found = true;
         }
      }
   }


   if(!found)
      return false;


   result = best;

   result.valid = true;

   return true;
}


//+------------------------------------------------------------------+
//| Main OB Scan                                                     |
//+------------------------------------------------------------------+
void ScanOrderBlock(
   ENUM_BIAS direction,
   LiquiditySweepState &sweep,
   StructureConfirmationState &structure,
   OrderBlockState &result
)
{
   ZeroMemory(result);

   result.valid = false;


   if(!sweep.valid)
      return;


   if(!structure.valid)
      return;


   if(direction != BIAS_BULLISH &&
      direction != BIAS_BEARISH)
   {
      return;
   }


   SelectBestOrderBlock(
      direction,
      sweep,
      structure,
      result
   );
}


//+------------------------------------------------------------------+
//| Convenience                                                      |
//+------------------------------------------------------------------+
bool HasValidOrderBlock()
{
   if(!g_OrderBlock.valid)
      return false;

   if(!g_OrderBlock.fresh)
      return false;

   if(!g_OrderBlock.unmitigated)
      return false;

   if(!g_OrderBlock.hasFVG)
      return false;

   if(!g_OrderBlock.fvgNearOB)
      return false;

   return true;
}


//+------------------------------------------------------------------+

#endif

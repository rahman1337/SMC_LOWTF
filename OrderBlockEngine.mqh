#ifndef SCALPINGEA_ORDER_BLOCK_ENGINE_MQH
#define SCALPINGEA_ORDER_BLOCK_ENGINE_MQH

#include “Constants.mqh”
#include “Structures.mqh”

//+——————————————————————+
//| Global OB State                                                  |
//+——————————————————————+
OrderBlockState g_OrderBlock;

//+——————————————————————+
//| Settings                                                         |
//+——————————————————————+

input group “=== M5 / M1 ORDER BLOCK + FVG ===”

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

//+——————————————————————+
//| ATR                                                              |
//+——————————————————————+

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

//+——————————————————————+
//| Candle direction                                                 |
//+——————————————————————+

bool IsBullishOBCandle(
ENUM_TIMEFRAMES timeframe,
int shift
)
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

return close > open;
}

//+——————————————————————+

bool IsBearishOBCandle(
ENUM_TIMEFRAMES timeframe,
int shift
)
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

return close < open;
}

//+——————————————————————+
//| Body                                                             |
//+——————————————————————+

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

//+——————————————————————+
//| Range                                                            |
//+——————————————————————+

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

//+——————————————————————+
//| FVG                                                              |
//+——————————————————————+

bool FindBullishOBFVG(
ENUM_TIMEFRAMES timeframe,
int middleShift,
double &fvgHigh,
double &fvgLow
)
{
fvgHigh = 0.0;
fvgLow  = 0.0;

if(middleShift < 2)
return false;

int olderShift =
middleShift + 1;

int newerShift =
middleShift - 1;

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

//+——————————————————————+

bool FindBearishOBFVG(
ENUM_TIMEFRAMES timeframe,
int middleShift,
double &fvgHigh,
double &fvgLow
)
{
fvgHigh = 0.0;
fvgLow  = 0.0;

if(middleShift < 2)
return false;

int olderShift =
middleShift + 1;

int newerShift =
middleShift - 1;

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

//+——————————————————————+
//| FVG overlaps OB                                                  |
//+——————————————————————+

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

//+——————————————————————+
//| FVG distance                                                     |
//+——————————————————————+

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

//+——————————————————————+
//| Validate OB / FVG relationship                                   |
//+——————————————————————+

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
beside   = true;
near     = true;

  return true;

}

return false;
}

//+——————————————————————+
//| OB mitigation                                                    |
//+——————————————————————+

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

/*
Only candles AFTER the OB are checked.

  Bullish OB:
  Price must not trade below the complete OB.
  Bearish OB:
  Price must not trade above the complete OB.

*/

for(int shift = obShift - 1;
shift >= 1;
shift–)
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

//+——————————————————————+
//| OB freshness                                                     |
//+——————————————————————+

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

//+——————————————————————+
//| OB exists between sweep and confirmation                         |
//+——————————————————————+

bool IsOBInsideStructureSequence(
ENUM_TIMEFRAMES timeframe,
int obShift,
StructureConfirmationState &structure
)
{
if(!structure.valid)
return false;

if(structure.sweepTime <= 0 ||
structure.confirmationTime <= 0)
{
return false;
}

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
*/

if(obTime <= structure.sweepTime)
return false;

/*
OB must be created BEFORE the
M5 structure confirmation.
*/

if(obTime >= structure.confirmationTime)
return false;

return true;
}

//+——————————————————————+
//| OB must precede confirmation                                     |
//+——————————————————————+

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

if(!IsOBInsideStructureSequence(
timeframe,
obShift,
structure
))
{
return false;
}

return true;
}

//+——————————————————————+
//| Search window                                                    |
//+——————————————————————+

void GetOBSearchWindow(
ENUM_TIMEFRAMES timeframe,
StructureConfirmationState &structure,
int &startShift,
int &endShift
)
{
startShift = 2;
endShift   = InpOBSearchBars;

if(!structure.valid)
return;

if(structure.confirmationTime <= 0)
return;

int confirmationShift =
iBarShift(
_Symbol,
timeframe,
structure.confirmationTime,
false
);

if(confirmationShift < 2)
confirmationShift = 2;

/*
IMPORTANT:

  Start one candle OLDER than the confirmation
  candle.
  The confirmation candle itself can never be
  the OB because the OB must already exist before
  the displacement / confirmation.

*/

startShift =
confirmationShift + 1;

int bars =
Bars(
_Symbol,
timeframe
);

if(bars <= startShift)
{
endShift =
startShift;

  return;

}

endShift =
MathMin(
InpOBSearchBars,
bars - 1
);

/*
Maximum OB age is measured from the present.
*/

endShift =
MathMin(
endShift,
startShift + InpOBMaximumAge
);
}

//+——————————————————————+
//| Find displacement AFTER OB and BEFORE confirmation               |
//+——————————————————————+

bool FindOBDisplacement(
ENUM_TIMEFRAMES timeframe,
ENUM_BIAS direction,
int obShift,
StructureConfirmationState &structure,
int &displacementShift,
double &displacementATR
)
{
displacementShift = -1;
displacementATR   = 0.0;

if(!structure.valid)
return false;

if(structure.confirmationTime <= 0)
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
Search from the OB toward the present.

  The displacement MUST be:
  - newer than the OB
  - not newer than confirmation
  - within the allowed displacement window

*/

int maxBars =
MathMin(
InpOBDisplacementBars,
obShift - confirmationShift
);

if(maxBars < 1)
return false;

for(int d = 1;
d <= maxBars;
d++)
{
int checkShift =
obShift - d;

  if(checkShift < confirmationShift)
     break;
  double open =
     iOpen(
        _Symbol,
        timeframe,
        checkShift
     );
  double close =
     iClose(
        _Symbol,
        timeframe,
        checkShift
     );
  double high =
     iHigh(
        _Symbol,
        timeframe,
        checkShift
     );
  double low =
     iLow(
        _Symbol,
        timeframe,
        checkShift
     );
  double range =
     high - low;
  if(range <= 0.0)
     continue;
  double body =
     MathAbs(
        close - open
     );
  double atr =
     GetOBATR(timeframe);
  if(atr <= 0.0)
     continue;
  double bodyATR =
     body / atr;
  if(bodyATR <
     InpOBMinimumBodyATR)
  {
     continue;
  }
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
     Require the displacement candle to actually
     have a meaningful body.
  */
  if(body / range < 0.50)
     continue;
  displacementShift =
     checkShift;
  displacementATR =
     bodyATR;
  return true;

}

return false;
}

//+——————————————————————+
//| Find FVG associated with displacement                            |
//+——————————————————————+

bool FindOBAssociatedFVG(
ENUM_TIMEFRAMES timeframe,
ENUM_BIAS direction,
int displacementShift,
int confirmationShift,
double obHigh,
double obLow,
double &fvgHigh,
double &fvgLow,
bool &fvgInside,
bool &fvgBeside,
bool &fvgNear,
double &fvgDistance
)
{
fvgHigh = 0.0;
fvgLow  = 0.0;

fvgInside  = false;
fvgBeside  = false;
fvgNear    = false;

fvgDistance = 0.0;

/*
Check the displacement candle and the next few
candles toward confirmation.

  This prevents an unrelated FVG elsewhere in the
  chart from being attached to the OB.

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
     Do not allow the FVG to come from before the
     displacement candle.
  */
  if(fvgShift > displacementShift + 3)
     continue;
  /*
     FVG must not be formed after confirmation.
  */
  if(fvgShift < confirmationShift)
     continue;
  double candidateHigh = 0.0;
  double candidateLow  = 0.0;
  bool found = false;
  if(direction == BIAS_BULLISH)
  {
     found =
        FindBullishOBFVG(
           timeframe,
           fvgShift,
           candidateHigh,
           candidateLow
        );
  }
  else
  if(direction == BIAS_BEARISH)
  {
     found =
        FindBearishOBFVG(
           timeframe,
           fvgShift,
           candidateHigh,
           candidateLow
        );
  }
  if(!found)
     continue;
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
  fvgHigh = candidateHigh;
  fvgLow  = candidateLow;
  fvgInside = inside;
  fvgBeside = beside;
  fvgNear   = near;
  fvgDistance = distance;
  return true;

}

return false;
}

//+——————————————————————+
//| Fill common OB state                                             |
//+——————————————————————+

void FillOBState(
ENUM_TIMEFRAMES timeframe,
ENUM_BIAS direction,
int shift,
int displacementShift,
double displacementATR,
bool hasFVG,
double fvgHigh,
double fvgLow,
bool fvgInside,
bool fvgBeside,
bool fvgNear,
double fvgDistance,
OrderBlockState &result
)
{
result.valid = true;

result.fresh =
IsOrderBlockFreshTF(
shift
);

result.unmitigated = true;

if(direction == BIAS_BULLISH)
{
result.type =
OB_BULLISH;

  result.direction =
     BIAS_BULLISH;

}
else
{
result.type =
OB_BEARISH;

  result.direction =
     BIAS_BEARISH;

}

result.high =
iHigh(
_Symbol,
timeframe,
shift
);

result.low =
iLow(
_Symbol,
timeframe,
shift
);

result.range =
result.high -
result.low;

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

result.displacementOrigin = true;

result.structureAligned = true;

result.hasFVG =
hasFVG;

result.fvgHigh =
fvgHigh;

result.fvgLow =
fvgLow;

result.fvgRange =
fvgHigh -
fvgLow;

result.fvgInsideOB =
fvgInside;

result.fvgBesideOB =
fvgBeside;

result.fvgNearOB =
fvgNear;

result.fvgDistance =
fvgDistance;

//===============================================================
// Score
//===============================================================

result.score = 0.0;

/*
Fresh
*/

if(result.fresh)
result.score += 20.0;

/*
Unmitigated
*/

if(result.unmitigated)
result.score += 20.0;

/*
Direct structure alignment
*/

if(result.structureAligned)
result.score += 20.0;

/*
Real displacement
*/

if(result.displacementOrigin)
result.score += 15.0;

/*
FVG
*/

if(hasFVG)
result.score += 15.0;

/*
FVG directly overlaps OB
*/

if(fvgInside)
result.score += 10.0;

if(result.score > 100.0)
result.score = 100.0;
}

//+——————————————————————+
//| Find bullish OB                                                  |
//+——————————————————————+

bool FindBullishOBTF(
ENUM_TIMEFRAMES timeframe,
StructureConfirmationState &structure,
OrderBlockState &result
)
{
ZeroMemory(result);

result.valid = false;

if(!structure.valid)
return false;

if(structure.direction !=
BIAS_BULLISH)
{
return false;
}

double atr =
GetOBATR(timeframe);

if(atr <= 0.0)
return false;

int startShift;
int endShift;

GetOBSearchWindow(
timeframe,
structure,
startShift,
endShift
);

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
Search from the confirmation backward.

  The FIRST valid bearish candle found is the
  nearest opposing candle associated with the
  confirmed bullish continuation.

*/

for(int shift = startShift;
shift <= endShift;
shift++)
{
if(!IsBearishOBCandle(
timeframe,
shift
))
{
continue;
}

  if(!IsOBInsideStructureSequence(
        timeframe,
        shift,
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
     obHigh -
     obLow;
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
  //=============================================================
  // Displacement
  //=============================================================
  int displacementShift = -1;
  double displacementATR = 0.0;
  if(!FindOBDisplacement(
        timeframe,
        BIAS_BULLISH,
        shift,
        structure,
        displacementShift,
        displacementATR
     ))
  {
     continue;
  }
  //=============================================================
  // FVG
  //=============================================================
  bool hasFVG = false;
  double fvgHigh = 0.0;
  double fvgLow  = 0.0;
  bool fvgInside = false;
  bool fvgBeside = false;
  bool fvgNear   = false;
  double fvgDistance = 0.0;
  hasFVG =
     FindOBAssociatedFVG(
        timeframe,
        BIAS_BULLISH,
        displacementShift,
        confirmationShift,
        obHigh,
        obLow,
        fvgHigh,
        fvgLow,
        fvgInside,
        fvgBeside,
        fvgNear,
        fvgDistance
     );
  if(InpRequireOBFVG &&
     !hasFVG)
  {
     continue;
  }
  //=============================================================
  // Final validation
  //=============================================================
  FillOBState(
     timeframe,
     BIAS_BULLISH,
     shift,
     displacementShift,
     displacementATR,
     hasFVG,
     fvgHigh,
     fvgLow,
     fvgInside,
     fvgBeside,
     fvgNear,
     fvgDistance,
     result
  );
  if(!result.valid)
     continue;
  return true;

}

return false;
}

//+——————————————————————+
//| Find bearish OB                                                  |
//+——————————————————————+

bool FindBearishOBTF(
ENUM_TIMEFRAMES timeframe,
StructureConfirmationState &structure,
OrderBlockState &result
)
{
ZeroMemory(result);

result.valid = false;

if(!structure.valid)
return false;

if(structure.direction !=
BIAS_BEARISH)
{
return false;
}

double atr =
GetOBATR(timeframe);

if(atr <= 0.0)
return false;

int startShift;
int endShift;

GetOBSearchWindow(
timeframe,
structure,
startShift,
endShift
);

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
Search from the confirmation backward.

  The FIRST valid bullish candle found is the
  nearest opposing candle associated with the
  confirmed bearish continuation.

*/

for(int shift = startShift;
shift <= endShift;
shift++)
{
if(!IsBullishOBCandle(
timeframe,
shift
))
{
continue;
}

  if(!IsOBInsideStructureSequence(
        timeframe,
        shift,
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
     obHigh -
     obLow;
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
  //=============================================================
  // Displacement
  //=============================================================
  int displacementShift = -1;
  double displacementATR = 0.0;
  if(!FindOBDisplacement(
        timeframe,
        BIAS_BEARISH,
        shift,
        structure,
        displacementShift,
        displacementATR
     ))
  {
     continue;
  }
  //=============================================================
  // FVG
  //=============================================================
  bool hasFVG = false;
  double fvgHigh = 0.0;
  double fvgLow  = 0.0;
  bool fvgInside = false;
  bool fvgBeside = false;
  bool fvgNear   = false;
  double fvgDistance = 0.0;
  hasFVG =
     FindOBAssociatedFVG(
        timeframe,
        BIAS_BEARISH,
        displacementShift,
        confirmationShift,
        obHigh,
        obLow,
        fvgHigh,
        fvgLow,
        fvgInside,
        fvgBeside,
        fvgNear,
        fvgDistance
     );
  if(InpRequireOBFVG &&
     !hasFVG)
  {
     continue;
  }
  //=============================================================
  // Final validation
  //=============================================================
  FillOBState(
     timeframe,
     BIAS_BEARISH,
     shift,
     displacementShift,
     displacementATR,
     hasFVG,
     fvgHigh,
     fvgLow,
     fvgInside,
     fvgBeside,
     fvgNear,
     fvgDistance,
     result
  );
  if(!result.valid)
     continue;
  return true;

}

return false;
}

//+——————————————————————+
//| Select strongest OB                                              |
//+——————————————————————+

bool SelectBestOrderBlock(
ENUM_BIAS direction,
StructureConfirmationState &structure,
OrderBlockState &result
)
{
ZeroMemory(result);

result.valid = false;

if(!structure.valid)
return false;

OrderBlockState best;

ZeroMemory(best);

bool found = false;

//===============================================================
// M5 ORDER BLOCK
//===============================================================

OrderBlockState m5;

ZeroMemory(m5);

bool m5Found = false;

if(direction == BIAS_BULLISH)
{
m5Found =
FindBullishOBTF(
PERIOD_M5,
structure,
m5
);
}
else
if(direction == BIAS_BEARISH)
{
m5Found =
FindBearishOBTF(
PERIOD_M5,
structure,
m5
);
}

if(m5Found)
{
best = m5;
found = true;
}

//===============================================================
// M1 REFINEMENT
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
           structure,
           m1
        );
  }
  if(m1Found)
  {
     /*
        M1 is a refinement.
        It may replace M5 only when it is genuinely
        stronger than the M5 candidate.
     */
     if(!found ||
        m1.score > best.score)
     {
        best = m1;
        found = true;
     }
  }

}

//===============================================================
// Nothing valid
//===============================================================

if(!found)
return false;

//===============================================================
// Final result
//===============================================================

result = best;

result.valid = true;

return true;
}

//+——————————————————————+
//| Main OB Scan                                                     |
//+——————————————————————+

void ScanOrderBlock(
ENUM_BIAS direction,
StructureConfirmationState &structure,
OrderBlockState &result
)
{
ZeroMemory(result);

result.valid = false;

if(!structure.valid)
return;

if(direction != BIAS_BULLISH &&
direction != BIAS_BEARISH)
{
return;
}

if(!SelectBestOrderBlock(
direction,
structure,
result
))
{
return;
}

/*
Final safety checks.
*/

if(!result.fresh)
{
result.valid = false;
return;
}

if(!result.unmitigated)
{
result.valid = false;
return;
}

if(InpRequireOBFVG &&
!result.hasFVG)
{
result.valid = false;
return;
}

if(InpRequireOBFVG &&
!result.fvgNearOB)
{
result.valid = false;
return;
}
}

//+——————————————————————+
//| Convenience                                                      |
//+——————————————————————+

bool HasValidOrderBlock()
{
if(!g_OrderBlock.valid)
return false;

if(!g_OrderBlock.fresh)
return false;

if(!g_OrderBlock.unmitigated)
return false;

if(InpRequireOBFVG)
{
if(!g_OrderBlock.hasFVG)
return false;

  if(!g_OrderBlock.fvgNearOB)
     return false;

}

if(g_OrderBlock.direction !=
BIAS_BULLISH &&
g_OrderBlock.direction !=
BIAS_BEARISH)
{
return false;
}

if(g_OrderBlock.high <=
g_OrderBlock.low)
{
return false;
}

return true;
}

//+——————————————————————+

#endif

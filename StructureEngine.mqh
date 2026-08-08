#ifndef SCALPINGEA_M5_STRUCTURE_ENGINE_MQH
#define SCALPINGEA_M5_STRUCTURE_ENGINE_MQH

#include “Constants.mqh”
#include “Structures.mqh”

//+——————————————————————+
//| Global Structure State                                           |
//+——————————————————————+

StructureConfirmationState g_Structure;

//+——————————————————————+
//| Settings                                                         |
//+——————————————————————+

input group “=== M5 Structure Confirmation ===”

input int    InpStructureLookback       = 3;
input int    InpStructureSearchBars     = 80;

input double InpMinimumDisplacementATR  = 0.50;
input double InpMinimumBreakATR         = 0.05;

input double InpIFVGMinimumGapATR       = 0.03;

input int    InpMaxConfirmationBars     = 6;

input bool   InpRequireDisplacement    = true;
input bool   InpRequireStructureBreak   = true;
input bool   InpAllowIFVGConfirmation   = true;

//+——————————————————————+
//| M5 Swing                                                         |
//+——————————————————————+

struct M5Swing
{
bool valid;

double price;

int shift;

datetime time;
};

//+——————————————————————+
//| Reset                                                            |
//+——————————————————————+

void ResetStructureState()
{
ZeroMemory(g_Structure);
}

//+——————————————————————+
//| ATR                                                              |
//+——————————————————————+

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

//+——————————————————————+
//| Candle Time                                                      |
//+——————————————————————+

datetime GetM5CandleTime(
int shift
)
{
if(shift < 0)
return 0;

return iTime(
_Symbol,
PERIOD_M5,
shift
);
}

//+——————————————————————+
//| Find M5 Swing High                                               |
//+——————————————————————+

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

if(startShift <
InpStructureLookback + 1)
{
startShift =
InpStructureLookback + 1;
}

if(startShift > maxShift)
return false;

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
     double newerHigh =
        iHigh(
           _Symbol,
           PERIOD_M5,
           shift - i
        );
     double olderHigh =
        iHigh(
           _Symbol,
           PERIOD_M5,
           shift + i
        );
     if(high <= newerHigh ||
        high <= olderHigh)
     {
        valid = false;
        break;
     }
  }
  if(!valid)
     continue;
  swing.valid = true;
  swing.price =
     high;
  swing.shift =
     shift;
  swing.time =
     GetM5CandleTime(
        shift
     );
  return true;

}

return false;
}

//+——————————————————————+
//| Find M5 Swing Low                                                |
//+——————————————————————+

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

if(startShift <
InpStructureLookback + 1)
{
startShift =
InpStructureLookback + 1;
}

if(startShift > maxShift)
return false;

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
     double newerLow =
        iLow(
           _Symbol,
           PERIOD_M5,
           shift - i
        );
     double olderLow =
        iLow(
           _Symbol,
           PERIOD_M5,
           shift + i
        );
     if(low >= newerLow ||
        low >= olderLow)
     {
        valid = false;
        break;
     }
  }
  if(!valid)
     continue;
  swing.valid = true;
  swing.price =
     low;
  swing.shift =
     shift;
  swing.time =
     GetM5CandleTime(
        shift
     );
  return true;

}

return false;
}

//+——————————————————————+
//| Find Most Recent Swing High BEFORE Sweep                         |
//+——————————————————————+

bool FindPreSweepSwingHigh(
datetime sweepTime,
M5Swing &swing
)
{
ZeroMemory(swing);

int sweepShift =
iBarShift(
_Symbol,
PERIOD_M5,
sweepTime,
false
);

if(sweepShift < 1)
return false;

/*
Start immediately before the sweep.

  We deliberately do NOT search from a large historical
  offset. The purpose is to identify the structure that
  existed immediately before the liquidity event.

*/

int startShift =
sweepShift + 1;

return FindM5SwingHigh(
startShift,
swing
);
}

//+——————————————————————+
//| Find Most Recent Swing Low BEFORE Sweep                          |
//+——————————————————————+

bool FindPreSweepSwingLow(
datetime sweepTime,
M5Swing &swing
)
{
ZeroMemory(swing);

int sweepShift =
iBarShift(
_Symbol,
PERIOD_M5,
sweepTime,
false
);

if(sweepShift < 1)
return false;

int startShift =
sweepShift + 1;

return FindM5SwingLow(
startShift,
swing
);
}

//+——————————————————————+
//| Strong Displacement                                              |
//+——————————————————————+

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

double range =
high - low;

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

/*
A displacement candle should actually travel.

  Requiring at least 50% body/range prevents a candle with
  a large ATR-sized wick but weak directional body from
  being treated as displacement.

*/

if((body / range) < 0.50)
return false;

return true;
}

//+——————————————————————+
//| Bullish Structure Break                                         |
//+——————————————————————+

bool DetectBullishStructureBreak(
double structureLevel,
datetime sweepTime,
int maxBars,
double &breakPrice,
int &breakShift
)
{
breakPrice = 0.0;
breakShift = -1;

if(structureLevel <= 0.0)
return false;

double atr =
GetStructureATR();

if(atr <= 0.0)
return false;

double minimumBreak =
atr * InpMinimumBreakATR;

int sweepShift =
iBarShift(
_Symbol,
PERIOD_M5,
sweepTime,
false
);

if(sweepShift < 1)
return false;

int bars =
Bars(
_Symbol,
PERIOD_M5
);

if(bars <= 0)
return false;

/*
maxBars is measured FROM THE SWEEP.

  We scan chronological order:
  oldest valid candle after sweep -> newest closed candle.
  This prevents a historical break from being selected.

*/

int oldestShift =
sweepShift - maxBars;

if(oldestShift < 1)
oldestShift = 1;

for(int shift = sweepShift - 1;
shift >= oldestShift;
shift–)
{
datetime candleTime =
GetM5CandleTime(
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
     structureLevel + minimumBreak)
  {
     breakPrice =
        close;
     breakShift =
        shift;
     return true;
  }

}

return false;
}

//+——————————————————————+
//| Bearish Structure Break                                         |
//+——————————————————————+

bool DetectBearishStructureBreak(
double structureLevel,
datetime sweepTime,
int maxBars,
double &breakPrice,
int &breakShift
)
{
breakPrice = 0.0;
breakShift = -1;

if(structureLevel <= 0.0)
return false;

double atr =
GetStructureATR();

if(atr <= 0.0)
return false;

double minimumBreak =
atr * InpMinimumBreakATR;

int sweepShift =
iBarShift(
_Symbol,
PERIOD_M5,
sweepTime,
false
);

if(sweepShift < 1)
return false;

int bars =
Bars(
_Symbol,
PERIOD_M5
);

if(bars <= 0)
return false;

int oldestShift =
sweepShift - maxBars;

if(oldestShift < 1)
oldestShift = 1;

for(int shift = sweepShift - 1;
shift >= oldestShift;
shift–)
{
datetime candleTime =
GetM5CandleTime(
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
     structureLevel - minimumBreak)
  {
     breakPrice =
        close;
     breakShift =
        shift;
     return true;
  }

}

return false;
}

//+——————————————————————+
//| Bullish FVG                                                      |
//+——————————————————————+

bool DetectBullishFVG(
int confirmationShift
)
{
if(confirmationShift < 1)
return false;

/*
We need three CLOSED candles.

  Older = confirmationShift + 2
  Middle = confirmationShift + 1
  Newer = confirmationShift
  Bullish FVG:
  newer low > older high

*/

int newer =
confirmationShift;

int middle =
confirmationShift + 1;

int older =
confirmationShift + 2;

if(Bars(
_Symbol,
PERIOD_M5
) <= older)
{
return false;
}

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

double atr =
GetStructureATR();

if(atr <= 0.0)
return false;

if(gap <
atr * InpIFVGMinimumGapATR)
{
return false;
}

return true;
}

//+——————————————————————+
//| Bearish FVG                                                      |
//+——————————————————————+

bool DetectBearishFVG(
int confirmationShift
)
{
if(confirmationShift < 1)
return false;

int newer =
confirmationShift;

int middle =
confirmationShift + 1;

int older =
confirmationShift + 2;

if(Bars(
_Symbol,
PERIOD_M5
) <= older)
{
return false;
}

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

double atr =
GetStructureATR();

if(atr <= 0.0)
return false;

if(gap <
atr * InpIFVGMinimumGapATR)
{
return false;
}

return true;
}

//+——————————————————————+
//| Bullish Post-Sweep IFVG                                         |
//+——————————————————————+

bool DetectBullishPostSweepIFVG(
datetime sweepTime,
int breakShift
)
{
if(!InpAllowIFVGConfirmation)
return false;

if(breakShift < 1)
return false;

/*
The imbalance must occur AFTER the liquidity sweep.

  We therefore inspect the confirmation candle and its
  immediate two-candle structure and explicitly reject
  anything formed before the sweep.

*/

if(!DetectBullishFVG(
breakShift
))
{
return false;
}

datetime gapTime =
GetM5CandleTime(
breakShift
);

if(gapTime <= sweepTime)
return false;

return true;
}

//+——————————————————————+
//| Bearish Post-Sweep IFVG                                         |
//+——————————————————————+

bool DetectBearishPostSweepIFVG(
datetime sweepTime,
int breakShift
)
{
if(!InpAllowIFVGConfirmation)
return false;

if(breakShift < 1)
return false;

if(!DetectBearishFVG(
breakShift
))
{
return false;
}

datetime gapTime =
GetM5CandleTime(
breakShift
);

if(gapTime <= sweepTime)
return false;

return true;
}

//+——————————————————————+
//| Determine Bullish Structure Type                                |
//+——————————————————————+

void DetermineBullishStructureType(
LiquiditySweepState &sweep,
M5Swing &preSweepHigh,
StructureConfirmationState &result
)
{
/*
After a sell-side sweep, price should reclaim structure.

  If the pre-sweep high is broken after the sweep, the event
  is treated as bullish MSS/CHOCH when the sweep represents
  a reversal from bearish order flow.
  We cannot truthfully label every break both BOS and CHOCH.
  Therefore:
  - MSS = structural reversal after liquidity sweep.
  - BOS = continuation break.
  - CHOCH = reversal-style structural change.
  With no separate higher/lower structure history available
  in the existing Structures contract, the conservative
  interpretation is:
  sweep + break of pre-sweep swing = MSS + CHOCH
  BOS remains false unless an additional continuation level
  is subsequently broken.

*/

result.mss = true;
result.choch = true;
result.bos = false;
}

//+——————————————————————+
//| Determine Bearish Structure Type                                |
//+——————————————————————+

void DetermineBearishStructureType(
LiquiditySweepState &sweep,
M5Swing &preSweepLow,
StructureConfirmationState &result
)
{
result.mss = true;
result.choch = true;
result.bos = false;
}

//+——————————————————————+
//| Confirm Bullish Structure                                        |
//+——————————————————————+

bool ConfirmBullishStructure(
LiquiditySweepState &sweep,
StructureConfirmationState &result
)
{
ZeroMemory(result);

result.valid = false;

if(!sweep.valid)
return false;

if(sweep.direction !=
BIAS_BULLISH)
{
return false;
}

if(sweep.sweepTime <= 0)
return false;

int sweepShift =
iBarShift(
_Symbol,
PERIOD_M5,
sweep.sweepTime,
false
);

if(sweepShift < 1)
return false;

/*
The sweep must be the initiating event.

  The confirmation structure must occur after the sweep.

*/

M5Swing swingHigh;

if(!FindPreSweepSwingHigh(
sweep.sweepTime,
swingHigh
))
{
return false;
}

/*
The structure level must be above the liquidity that was
swept. Otherwise the “break” would not represent a meaningful
reclaim of opposing structure.
*/

if(swingHigh.price <=
sweep.liquidityPrice)
{
return false;
}

double breakPrice = 0.0;

int breakShift = -1;

if(!DetectBullishStructureBreak(
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

bool displacement =
IsStrongDisplacement(
breakShift,
BIAS_BULLISH,
displacementATR
);

if(InpRequireDisplacement &&
!displacement)
{
return false;
}

bool ifvg =
DetectBullishPostSweepIFVG(
sweep.sweepTime,
breakShift
);

/*
At least one genuine structural event is mandatory.
The structure break itself is the primary confirmation.
*/

if(InpRequireStructureBreak)
{
if(breakShift < 1 ||
breakPrice <= 0.0)
{
return false;
}
}

//===============================================================
// Fill result
//===============================================================

result.valid = true;

result.direction =
BIAS_BULLISH;

result.sweepTime =
sweep.sweepTime;

result.sweepShift =
sweepShift;

result.structureBreak =
true;

DetermineBullishStructureType(
sweep,
swingHigh,
result
);

result.ifvg =
ifvg;

result.displacement =
displacement;

result.confirmationCandle =
true;

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
GetM5CandleTime(
breakShift
);

result.timeframe =
PERIOD_M5;

//===============================================================
// Score
//===============================================================

result.score = 0;

/*
Structure break = primary confirmation.
*/

result.score += 35;

/*
MSS / CHOCH = reversal confirmation.
*/

if(result.mss)
result.score += 20;

if(result.choch)
result.score += 15;

/*
Displacement = quality confirmation.
*/

if(result.displacement)
result.score += 15;

/*
IFVG = additional confirmation, not mandatory.
*/

if(result.ifvg)
result.score += 15;

if(result.score > 100)
result.score = 100;

return true;
}

//+——————————————————————+
//| Confirm Bearish Structure                                        |
//+——————————————————————+

bool ConfirmBearishStructure(
LiquiditySweepState &sweep,
StructureConfirmationState &result
)
{
ZeroMemory(result);

result.valid = false;

if(!sweep.valid)
return false;

if(sweep.direction !=
BIAS_BEARISH)
{
return false;
}

if(sweep.sweepTime <= 0)
return false;

int sweepShift =
iBarShift(
_Symbol,
PERIOD_M5,
sweep.sweepTime,
false
);

if(sweepShift < 1)
return false;

M5Swing swingLow;

if(!FindPreSweepSwingLow(
sweep.sweepTime,
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

if(!DetectBearishStructureBreak(
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

bool displacement =
IsStrongDisplacement(
breakShift,
BIAS_BEARISH,
displacementATR
);

if(InpRequireDisplacement &&
!displacement)
{
return false;
}

bool ifvg =
DetectBearishPostSweepIFVG(
sweep.sweepTime,
breakShift
);

if(InpRequireStructureBreak)
{
if(breakShift < 1 ||
breakPrice <= 0.0)
{
return false;
}
}

//===============================================================
// Fill result
//===============================================================

result.valid = true;

result.direction =
BIAS_BEARISH;

result.sweepTime =
sweep.sweepTime;

result.sweepShift =
sweepShift;

result.structureBreak =
true;

DetermineBearishStructureType(
sweep,
swingLow,
result
);

result.ifvg =
ifvg;

result.displacement =
displacement;

result.confirmationCandle =
true;

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
GetM5CandleTime(
breakShift
);

result.timeframe =
PERIOD_M5;

//===============================================================
// Score
//===============================================================

result.score = 0;

result.score += 35;

if(result.mss)
result.score += 20;

if(result.choch)
result.score += 15;

if(result.displacement)
result.score += 15;

if(result.ifvg)
result.score += 15;

if(result.score > 100)
result.score = 100;

return true;
}

//+——————————————————————+
//| Main M5 Structure Scan                                           |
//+——————————————————————+

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

if(allowedDirection ==
BIAS_BULLISH)
{
ConfirmBullishStructure(
sweep,
result
);

  return;

}

if(allowedDirection ==
BIAS_BEARISH)
{
ConfirmBearishStructure(
sweep,
result
);

  return;

}
}

//+——————————————————————+
//| Confirm Current Liquidity Sweep                                  |
//+——————————————————————+

bool ConfirmM5Structure()
{
ZeroMemory(
g_Structure
);

if(!g_Liquidity.valid)
return false;

ScanM5Structure(
g_Liquidity.direction,
g_Liquidity,
g_Structure
);

return g_Structure.valid;
}

//+——————————————————————+
//| Get Structure Confirmation Score                                 |
//+——————————————————————+

double GetStructureConfirmationScore()
{
if(!g_Structure.valid)
return 0.0;

return g_Structure.score;
}

//+——————————————————————+
//| Get Structure Direction                                          |
//+——————————————————————+

ENUM_BIAS GetStructureDirection()
{
if(!g_Structure.valid)
return BIAS_NONE;

return g_Structure.direction;
}

//+——————————————————————+
//| Is Structure Confirmed                                           |
//+——————————————————————+

bool IsStructureConfirmed()
{
return g_Structure.valid;
}

//+——————————————————————+

#endif

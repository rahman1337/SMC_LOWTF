#ifndef SCALPINGEA_STRUCTURES_MQH
#define SCALPINGEA_STRUCTURES_MQH

#include "Constants.mqh"

//+------------------------------------------------------------------+
//| Liquidity Sweep State                                            |
//+------------------------------------------------------------------+
struct LiquiditySweepState
{
   bool valid;

   bool h4Liquidity;
   bool h1Liquidity;
   bool sessionLiquidity;
   bool asiaLiquidity;
   bool londonLiquidity;
   bool newYorkLiquidity;

   ENUM_LIQUIDITY_TYPE type;
   ENUM_BIAS direction;

   double liquidityPrice;

   datetime liquidityTime;
   datetime sweepTime;

   ENUM_TIMEFRAMES sourceTimeframe;

   double sweepHigh;
   double sweepLow;

   double candleOpen;
   double candleHigh;
   double candleLow;
   double candleClose;

   double candleRange;
   double bodySize;
   double upperWick;
   double lowerWick;

   double penetration;
   double rejectionDistance;

   bool closedBackInside;
   bool strongRejection;
   bool displacement;
   bool meaningfulLiquidity;
   bool oldLiquidity;
   bool inducementRisk;

   int liquidityAge;

   bool displacementConfirmed;
   bool mssConfirmed;
   bool bosConfirmed;
   bool chochConfirmed;
   bool ifvgConfirmed;

   int confirmationCount;

   bool phase3Confirmed;

   ENUM_SWEEP_QUALITY quality;

   int score;
};

//+------------------------------------------------------------------+
//| H4 Liquidity State                                               |
//+------------------------------------------------------------------+
struct H4LiquidityState
{
   bool valid;

   bool buySideAvailable;
   bool sellSideAvailable;

   double buySidePrice;
   double sellSidePrice;

   datetime buySideTime;
   datetime sellSideTime;

   int buySideShift;
   int sellSideShift;

   bool buySideSwept;
   bool sellSideSwept;

   double sweptPrice;

   datetime sweepTime;

   ENUM_LIQUIDITY_TYPE sweepType;

   ENUM_BIAS direction;

   ENUM_SWEEP_QUALITY quality;
};

//+------------------------------------------------------------------+
//| H1 Liquidity State                                               |
//+------------------------------------------------------------------+
struct H1LiquidityState
{
   bool valid;

   bool buySideAvailable;
   bool sellSideAvailable;

   double buySidePrice;
   double sellSidePrice;

   datetime buySideTime;
   datetime sellSideTime;

   int buySideShift;
   int sellSideShift;

   bool buySideSwept;
   bool sellSideSwept;

   double sweptPrice;

   datetime sweepTime;

   ENUM_LIQUIDITY_TYPE sweepType;

   ENUM_BIAS direction;

   ENUM_SWEEP_QUALITY quality;
};

//+------------------------------------------------------------------+
//| Session Liquidity State                                          |
//+------------------------------------------------------------------+
struct SessionLiquidityState
{
   bool valid;

   bool buySideAvailable;
   bool sellSideAvailable;

   double buySidePrice;
   double sellSidePrice;

   datetime buySideTime;
   datetime sellSideTime;

   bool buySideSwept;
   bool sellSideSwept;

   double sweptPrice;

   datetime sweepTime;

   ENUM_LIQUIDITY_TYPE sweepType;

   ENUM_BIAS direction;

   ENUM_SWEEP_QUALITY quality;

   string sessionName;
};

//+------------------------------------------------------------------+
//| Complete Liquidity Environment                                   |
//+------------------------------------------------------------------+
struct LiquidityEnvironmentState
{
   bool valid;

   H4LiquidityState h4;
   H1LiquidityState h1;
   SessionLiquidityState session;

   bool selected;

   ENUM_LIQUIDITY_TYPE selectedType;
   ENUM_BIAS selectedDirection;
   ENUM_TIMEFRAMES selectedTimeframe;

   double selectedPrice;

   datetime selectedTime;

   ENUM_SWEEP_QUALITY selectedQuality;

   int selectedScore;

   bool h4Confirmed;
   bool h1Confirmed;
   bool sessionConfirmed;

   int confirmedSweepCount;
};

//+------------------------------------------------------------------+
//| Global Liquidity States                                          |
//+------------------------------------------------------------------+
LiquiditySweepState       g_Liquidity;
LiquidityEnvironmentState g_LiquidityEnvironment;

//+------------------------------------------------------------------+
//| M5 Structure Confirmation                                       |
//+------------------------------------------------------------------+
struct StructureConfirmationState
{
   bool valid;

   bool bos;
   bool mss;
   bool choch;
   bool ifvg;
   bool displacement;
   bool structureBreak;
   bool confirmationCandle;

   ENUM_BIAS direction;

   //--- Liquidity sweep reference
   datetime sweepTime;
   int sweepShift;

   //--- Structure
   double brokenSwing;
   double breakPrice;

   double displacementSize;
   double displacementATR;

   datetime confirmationTime;

   ENUM_TIMEFRAMES timeframe;

   int score;
};

//+------------------------------------------------------------------+
//| Order Block State                                                |
//+------------------------------------------------------------------+
struct OrderBlockState
{
   bool valid;

   bool fresh;
   bool unmitigated;

   ENUM_OB_TYPE type;
   ENUM_BIAS direction;

   double high;
   double low;
   double range;

   int shift;

   datetime createdTime;

   double open;
   double close;

   bool displacementOrigin;
   bool structureAligned;

   bool hasFVG;

   double fvgHigh;
   double fvgLow;
   double fvgRange;

   bool fvgInsideOB;
   bool fvgBesideOB;
   bool fvgNearOB;

   double fvgDistance;

   double score;
};

//+------------------------------------------------------------------+
//| Entry Confirmation State                                         |
//+------------------------------------------------------------------+
struct EntryConfirmationState
{
   bool valid;

   bool priceInsideOB;
   bool m5TouchedOB;
   bool m5StrongRejection;
   bool m1StrongRejection;

   bool m1Confirmation;
   bool m5Confirmation;

   bool zoneHeld;

   ENUM_BIAS direction;

   double entryPrice;

   double stopLoss;
   double takeProfit;

   double obHigh;
   double obLow;

   double rejectionHigh;
   double rejectionLow;

   double rejectionWick;
   double rejectionBody;

   double stopBuffer;

   datetime confirmationTime;

   int score;
};

//+------------------------------------------------------------------+
//| Setup State                                                       |
//+------------------------------------------------------------------+
struct SetupState
{
   bool active;
   bool traded;
   bool expired;

   ulong setupID;

   ENUM_BIAS direction;

   datetime createdTime;
   datetime expiryTime;

   //--- Liquidity
   bool liquidityConfirmed;

   ENUM_LIQUIDITY_TYPE liquidityType;
   ENUM_TIMEFRAMES liquidityTimeframe;

   double liquidityPrice;

   datetime liquidityTime;

   bool h4LiquidityConfirmed;
   bool h1LiquidityConfirmed;
   bool sessionLiquidityConfirmed;

   //--- Structure
   bool structureConfirmed;

   bool bosConfirmed;
   bool mssConfirmed;
   bool chochConfirmed;
   bool ifvgConfirmed;

   double structureBreakPrice;

   datetime structureTime;

   //--- OB
   bool orderBlockConfirmed;

   double obHigh;
   double obLow;

   datetime obCreatedTime;

   //--- FVG
   bool fvgConfirmed;

   double fvgHigh;
   double fvgLow;

   //--- Entry
   bool entryConfirmed;

   double entryPrice;
   double stopLoss;
   double takeProfit;

   //--- Trade
   double lotSize;

   ulong positionTicket;
};

//+------------------------------------------------------------------+

#endif
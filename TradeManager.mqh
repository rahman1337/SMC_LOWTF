
#ifndef SCALPINGEA_TRADE_MANAGER_MQH
#define SCALPINGEA_TRADE_MANAGER_MQH

#include "Constants.mqh"
#include "Structures.mqh"
#include <Trade/Trade.mqh>

CTrade g_Trade;

//+------------------------------------------------------------------+
//| Trade Management Settings                                        |
//+------------------------------------------------------------------+

input group "=== Trade Management ==="

input double InpRiskRewardTP   = 3.0;

input double InpBreakEvenR     = 0.5;

input double InpLockR1Trigger  = 1.5;
input double InpLockR1Level    = 1.0;

input double InpLockR15Trigger = 2.0;
input double InpLockR15Level   = 1.5;

input double InpLockR2Trigger  = 2.5;
input double InpLockR2Level    = 2.0;


//+------------------------------------------------------------------+
//| Trade Management State                                           |
//+------------------------------------------------------------------+

struct TradeManagementState
{
   bool active;

   ulong ticket;

   ENUM_BIAS direction;

   double entryPrice;
   double initialSL;
   double currentSL;
   double takeProfit;

   double riskDistance;
   double currentR;

   bool breakEvenDone;
   bool lockR1Done;
   bool lockR15Done;
   bool lockR2Done;
};


//+------------------------------------------------------------------+
//| Global Trade Management State                                    |
//+------------------------------------------------------------------+

TradeManagementState g_TradeManagement;


//+------------------------------------------------------------------+
//| Reset Trade Management                                           |
//+------------------------------------------------------------------+

void ResetTradeManagement()
{
   ZeroMemory(g_TradeManagement);

   g_TradeManagement.active = false;
   g_TradeManagement.ticket = 0;
}


//+------------------------------------------------------------------+
//| Check Position Belongs To This EA                                |
//+------------------------------------------------------------------+

bool IsEAPositionByTicket(
   ulong ticket
)
{
   if(ticket == 0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   string symbol =
      PositionGetString(POSITION_SYMBOL);

   if(symbol != _Symbol)
      return false;

   ulong magic =
      (ulong)PositionGetInteger(
         POSITION_MAGIC
      );

   if(magic != g_Trade.RequestMagic())
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| Find EA Position Ticket                                          |
//+------------------------------------------------------------------+

ulong FindEAPositionTicket()
{
   for(int i = PositionsTotal() - 1;
       i >= 0;
       i--)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(symbol != _Symbol)
         continue;

      ulong magic =
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         );

      if(magic != g_Trade.RequestMagic())
         continue;

      return ticket;
   }

   return 0;
}


//+------------------------------------------------------------------+
//| Detect Position Direction                                        |
//+------------------------------------------------------------------+

ENUM_BIAS GetPositionBias()
{
   ulong ticket =
      FindEAPositionTicket();

   if(ticket == 0)
      return BIAS_NONE;

   if(!PositionSelectByTicket(ticket))
      return BIAS_NONE;

   ENUM_POSITION_TYPE type =
      (ENUM_POSITION_TYPE)
      PositionGetInteger(
         POSITION_TYPE
      );

   if(type == POSITION_TYPE_BUY)
      return BIAS_BULLISH;

   if(type == POSITION_TYPE_SELL)
      return BIAS_BEARISH;

   return BIAS_NONE;
}


//+------------------------------------------------------------------+
//| Calculate R Price                                                |
//+------------------------------------------------------------------+

double CalculateRPrice(
   ENUM_BIAS direction,
   double entry,
   double risk,
   double r
)
{
   if(direction == BIAS_BULLISH)
      return entry + (risk * r);

   if(direction == BIAS_BEARISH)
      return entry - (risk * r);

   return entry;
}


//+------------------------------------------------------------------+
//| Calculate Current R                                              |
//+------------------------------------------------------------------+

double CalculateCurrentR(
   ENUM_BIAS direction,
   double entry,
   double risk,
   double price
)
{
   if(risk <= 0.0)
      return 0.0;

   if(direction == BIAS_BULLISH)
      return (price - entry) / risk;

   if(direction == BIAS_BEARISH)
      return (entry - price) / risk;

   return 0.0;
}


//+------------------------------------------------------------------+
//| Initialize Trade Management                                     |
//+------------------------------------------------------------------+

bool InitializeTradeManagement(
   ulong ticket,
   ENUM_BIAS direction,
   double entryPrice,
   double stopLoss
)
{
   if(ticket == 0)
      return false;

   if(direction == BIAS_NONE)
      return false;

   if(entryPrice <= 0.0 ||
      stopLoss <= 0.0)
   {
      return false;
   }

   if(!IsEAPositionByTicket(ticket))
      return false;

   double risk =
      MathAbs(
         entryPrice - stopLoss
      );

   if(risk <= 0.0)
      return false;

   g_TradeManagement.active =
      true;

   g_TradeManagement.ticket =
      ticket;

   g_TradeManagement.direction =
      direction;

   g_TradeManagement.entryPrice =
      entryPrice;

   g_TradeManagement.initialSL =
      stopLoss;

   g_TradeManagement.currentSL =
      stopLoss;

   g_TradeManagement.riskDistance =
      risk;

   g_TradeManagement.takeProfit =
      CalculateRPrice(
         direction,
         entryPrice,
         risk,
         InpRiskRewardTP
      );

   g_TradeManagement.currentR =
      0.0;

   g_TradeManagement.breakEvenDone =
      false;

   g_TradeManagement.lockR1Done =
      false;

   g_TradeManagement.lockR15Done =
      false;

   g_TradeManagement.lockR2Done =
      false;

   return true;
}


//+------------------------------------------------------------------+
//| Validate SL Direction                                            |
//+------------------------------------------------------------------+

bool IsValidStopForDirection(
   ENUM_BIAS direction,
   double stopLoss,
   double entry
)
{
   if(direction == BIAS_BULLISH)
      return stopLoss < entry;

   if(direction == BIAS_BEARISH)
      return stopLoss > entry;

   return false;
}


//+------------------------------------------------------------------+
//| Validate TP Direction                                            |
//+------------------------------------------------------------------+

bool IsValidTPForDirection(
   ENUM_BIAS direction,
   double takeProfit,
   double entry
)
{
   if(direction == BIAS_BULLISH)
      return takeProfit > entry;

   if(direction == BIAS_BEARISH)
      return takeProfit < entry;

   return false;
}


//+------------------------------------------------------------------+
//| Normalize Trade Price                                            |
//+------------------------------------------------------------------+

double NormalizeTradePrice(
   double price
)
{
   int digits =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS
      );

   return NormalizeDouble(
      price,
      digits
   );
}


//+------------------------------------------------------------------+
//| Check Broker Stop Distance                                       |
//+------------------------------------------------------------------+

bool IsStopDistanceValid(
   ENUM_BIAS direction,
   double stopLoss
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

   long stopsLevel =
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      );

   double point =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT
      );

   if(bid <= 0.0 ||
      ask <= 0.0 ||
      point <= 0.0)
   {
      return false;
   }

   double minimumDistance =
      stopsLevel * point;

   // BUY SL is evaluated from BID.
   if(direction == BIAS_BULLISH)
   {
      if(stopLoss >= bid)
         return false;

      if((bid - stopLoss) <
         minimumDistance)
      {
         return false;
      }

      return true;
   }

   // SELL SL is evaluated from ASK.
   if(direction == BIAS_BEARISH)
   {
      if(stopLoss <= ask)
         return false;

      if((stopLoss - ask) <
         minimumDistance)
      {
         return false;
      }

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Modify Specific Position Stops                                   |
//+------------------------------------------------------------------+

bool ModifyPositionStops(
   double newSL,
   double newTP
)
{
   if(!g_TradeManagement.active)
      return false;

   ulong ticket =
      g_TradeManagement.ticket;

   if(!IsEAPositionByTicket(ticket))
      return false;

   newSL =
      NormalizeTradePrice(
         newSL
      );

   newTP =
      NormalizeTradePrice(
         newTP
      );

   if(!IsValidStopForDirection(
         g_TradeManagement.direction,
         newSL,
         g_TradeManagement.entryPrice
      ))
   {
      return false;
   }

   if(!IsValidTPForDirection(
         g_TradeManagement.direction,
         newTP,
         g_TradeManagement.entryPrice
      ))
   {
      return false;
   }

   if(!IsStopDistanceValid(
         g_TradeManagement.direction,
         newSL
      ))
   {
      return false;
   }

   if(!g_Trade.PositionModify(
         ticket,
         newSL,
         newTP
      ))
   {
      Print(
         "TradeManagement: PositionModify failed. ",
         "Ticket=",
         ticket,
         " | Retcode=",
         g_Trade.ResultRetcode(),
         " | ",
         g_Trade.ResultRetcodeDescription()
      );

      return false;
   }

   return true;
}


//+------------------------------------------------------------------+
//| Move SL To Breakeven                                             |
//+------------------------------------------------------------------+

bool MoveSLToBreakeven()
{
   if(g_TradeManagement.breakEvenDone)
      return true;

   double newSL =
      g_TradeManagement.entryPrice;

   if(!ModifyPositionStops(
         newSL,
         g_TradeManagement.takeProfit
      ))
   {
      return false;
   }

   g_TradeManagement.currentSL =
      newSL;

   g_TradeManagement.breakEvenDone =
      true;

   Print(
      "TradeManagement: ",
      "R0.5 reached -> SL moved to BE."
   );

   return true;
}


//+------------------------------------------------------------------+
//| Move SL To R1                                                    |
//+------------------------------------------------------------------+

bool MoveSLToR1()
{
   if(g_TradeManagement.lockR1Done)
      return true;

   double newSL =
      CalculateRPrice(
         g_TradeManagement.direction,
         g_TradeManagement.entryPrice,
         g_TradeManagement.riskDistance,
         InpLockR1Level
      );

   if(!ModifyPositionStops(
         newSL,
         g_TradeManagement.takeProfit
      ))
   {
      return false;
   }

   g_TradeManagement.currentSL =
      newSL;

   g_TradeManagement.lockR1Done =
      true;

   Print(
      "TradeManagement: ",
      "R1.5 reached -> SL moved to R1."
   );

   return true;
}


//+------------------------------------------------------------------+
//| Move SL To R1.5                                                  |
//+------------------------------------------------------------------+

bool MoveSLToR15()
{
   if(g_TradeManagement.lockR15Done)
      return true;

   double newSL =
      CalculateRPrice(
         g_TradeManagement.direction,
         g_TradeManagement.entryPrice,
         g_TradeManagement.riskDistance,
         InpLockR15Level
      );

   if(!ModifyPositionStops(
         newSL,
         g_TradeManagement.takeProfit
      ))
   {
      return false;
   }

   g_TradeManagement.currentSL =
      newSL;

   g_TradeManagement.lockR15Done =
      true;

   Print(
      "TradeManagement: ",
      "R2.0 reached -> SL moved to R1.5."
   );

   return true;
}


//+------------------------------------------------------------------+
//| Move SL To R2                                                    |
//+------------------------------------------------------------------+

bool MoveSLToR2()
{
   if(g_TradeManagement.lockR2Done)
      return true;

   double newSL =
      CalculateRPrice(
         g_TradeManagement.direction,
         g_TradeManagement.entryPrice,
         g_TradeManagement.riskDistance,
         InpLockR2Level
      );

   if(!ModifyPositionStops(
         newSL,
         g_TradeManagement.takeProfit
      ))
   {
      return false;
   }

   g_TradeManagement.currentSL =
      newSL;

   g_TradeManagement.lockR2Done =
      true;

   Print(
      "TradeManagement: ",
      "R2.5 reached -> SL moved to R2."
   );

   return true;
}


//+------------------------------------------------------------------+
//| Manage Active Trade                                              |
//+------------------------------------------------------------------+

void ManageActiveTrade()
{
   if(!g_TradeManagement.active)
      return;

   ulong ticket =
      g_TradeManagement.ticket;

   if(!IsEAPositionByTicket(ticket))
   {
      ResetTradeManagement();
      return;
   }

   if(!PositionSelectByTicket(ticket))
      return;

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

   double price =
      g_TradeManagement.direction ==
      BIAS_BULLISH
      ? bid
      : ask;

   if(price <= 0.0)
      return;

   g_TradeManagement.currentR =
      CalculateCurrentR(
         g_TradeManagement.direction,
         g_TradeManagement.entryPrice,
         g_TradeManagement.riskDistance,
         price
      );

   double currentR =
      g_TradeManagement.currentR;


   //===============================================================
   // R0.5 -> BREAKEVEN
   //===============================================================

   if(!g_TradeManagement.breakEvenDone &&
      currentR >= InpBreakEvenR)
   {
      MoveSLToBreakeven();
   }


   //===============================================================
   // R1.5 -> LOCK R1
   //===============================================================

   if(!g_TradeManagement.lockR1Done &&
      currentR >= InpLockR1Trigger)
   {
      MoveSLToR1();
   }


   //===============================================================
   // R2.0 -> LOCK R1.5
   //===============================================================

   if(!g_TradeManagement.lockR15Done &&
      currentR >= InpLockR15Trigger)
   {
      MoveSLToR15();
   }


   //===============================================================
   // R2.5 -> LOCK R2
   //===============================================================

   if(!g_TradeManagement.lockR2Done &&
      currentR >= InpLockR2Trigger)
   {
      MoveSLToR2();
   }
}


//+------------------------------------------------------------------+
//| Detect New EA Position                                           |
//+------------------------------------------------------------------+

bool DetectAndInitializeTrade()
{
   ulong ticket =
      FindEAPositionTicket();

   if(ticket == 0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   // Already initialized.
   if(g_TradeManagement.active &&
      g_TradeManagement.ticket == ticket)
   {
      return true;
   }


   ENUM_POSITION_TYPE type =
      (ENUM_POSITION_TYPE)
      PositionGetInteger(
         POSITION_TYPE
      );

   ENUM_BIAS direction =
      BIAS_NONE;

   if(type == POSITION_TYPE_BUY)
      direction = BIAS_BULLISH;

   else
   if(type == POSITION_TYPE_SELL)
      direction = BIAS_BEARISH;

   else
      return false;


   double entry =
      PositionGetDouble(
         POSITION_PRICE_OPEN
      );

   double sl =
      PositionGetDouble(
         POSITION_SL
      );

   double tp =
      PositionGetDouble(
         POSITION_TP
      );

   if(entry <= 0.0 ||
      sl <= 0.0)
   {
      return false;
   }


   if(!InitializeTradeManagement(
         ticket,
         direction,
         entry,
         sl
      ))
   {
      return false;
   }


   //===============================================================
   // Trade Manager uses fixed R3 TP.
   //===============================================================

   double fixedTP =
      g_TradeManagement.takeProfit;

   if(tp <= 0.0 ||
      MathAbs(
         tp - fixedTP
      ) >
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT
      ))
   {
      if(IsValidTPForDirection(
            direction,
            fixedTP,
            entry
         ))
      {
         if(IsStopDistanceValid(
               direction,
               sl
            ))
         {
            g_Trade.PositionModify(
               ticket,
               sl,
               NormalizeTradePrice(
                  fixedTP
               )
            );
         }
      }
   }


   g_TradeManagement.takeProfit =
      fixedTP;


   Print(
      "TradeManagement initialized | ",
      "Ticket=",
      ticket,
      " | Entry=",
      entry,
      " | Initial SL=",
      sl,
      " | Fixed TP R3=",
      fixedTP,
      " | Risk=",
      g_TradeManagement.riskDistance
   );

   return true;
}


//+------------------------------------------------------------------+
//| Main Trade Management                                            |
//+------------------------------------------------------------------+

void UpdateTradeManagement()
{
   if(!g_TradeManagement.active)
   {
      DetectAndInitializeTrade();
   }

   ManageActiveTrade();
}


//+------------------------------------------------------------------+
//| Check Trade Management Active                                    |
//+------------------------------------------------------------------+

bool IsTradeManagementActive()
{
   if(!g_TradeManagement.active)
      return false;

   return IsEAPositionByTicket(
      g_TradeManagement.ticket
   );
}


//+------------------------------------------------------------------+
//| Get Current R                                                    |
//+------------------------------------------------------------------+

double GetManagedTradeR()
{
   if(!g_TradeManagement.active)
      return 0.0;

   return g_TradeManagement.currentR;
}


//+------------------------------------------------------------------+
//| Get Current Managed SL                                           |
//+------------------------------------------------------------------+

double GetManagedTradeSL()
{
   return g_TradeManagement.currentSL;
}


//+------------------------------------------------------------------+
//| Get Managed TP                                                   |
//+------------------------------------------------------------------+

double GetManagedTradeTP()
{
   return g_TradeManagement.takeProfit;
}


//+------------------------------------------------------------------+
//| Cleanup After Position Closes                                    |
//+------------------------------------------------------------------+

void CleanupTradeManagement()
{
   if(g_TradeManagement.active)
   {
      if(IsEAPositionByTicket(
            g_TradeManagement.ticket
         ))
      {
         return;
      }
   }

   ResetTradeManagement();
}


//+------------------------------------------------------------------+

#endif


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


TradeManagementState g_TradeManagement;


//+------------------------------------------------------------------+
//| Reset                                                            |
//+------------------------------------------------------------------+

void ResetTradeManagement()
{
   ZeroMemory(g_TradeManagement);

   g_TradeManagement.active = false;
   g_TradeManagement.ticket = 0;
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
//| Check EA Position                                                |
//+------------------------------------------------------------------+

bool IsEAPositionByTicket(
   ulong ticket
)
{
   if(ticket == 0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
//| Find EA Position                                                 |
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

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
//| Get Position Direction                                           |
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
   if(entry <= 0.0 ||
      risk <= 0.0)
   {
      return 0.0;
   }

   if(direction == BIAS_BULLISH)
      return entry + (risk * r);

   if(direction == BIAS_BEARISH)
      return entry - (risk * r);

   return 0.0;
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
   if(entry <= 0.0 ||
      risk <= 0.0 ||
      price <= 0.0)
   {
      return 0.0;
   }

   if(direction == BIAS_BULLISH)
      return (price - entry) / risk;

   if(direction == BIAS_BEARISH)
      return (entry - price) / risk;

   return 0.0;
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
//| Broker Stop Distance                                             |
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

   double point =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT
      );

   long stopsLevel =
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      );

   if(bid <= 0.0 ||
      ask <= 0.0 ||
      point <= 0.0)
   {
      return false;
   }

   double minimumDistance =
      stopsLevel * point;


   // BUY SL is measured from BID.
   if(direction == BIAS_BULLISH)
   {
      if(stopLoss >= bid)
         return false;

      if((bid - stopLoss) < minimumDistance)
         return false;

      return true;
   }


   // SELL SL is measured from ASK.
   if(direction == BIAS_BEARISH)
   {
      if(stopLoss <= ask)
         return false;

      if((stopLoss - ask) < minimumDistance)
         return false;

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Initialize From Actual Position                                  |
//+------------------------------------------------------------------+

bool InitializeTradeManagement(
   ulong ticket
)
{
   if(ticket == 0)
      return false;

   if(!IsEAPositionByTicket(ticket))
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;


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


   double risk =
      MathAbs(
         entry - sl
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
      entry;

   g_TradeManagement.initialSL =
      sl;

   g_TradeManagement.currentSL =
      sl;

   g_TradeManagement.riskDistance =
      risk;

   // Prefer actual broker TP.
   if(tp > 0.0)
   {
      g_TradeManagement.takeProfit =
         tp;
   }
   else
   {
      g_TradeManagement.takeProfit =
         CalculateRPrice(
            direction,
            entry,
            risk,
            InpRiskRewardTP
         );
   }

   g_TradeManagement.currentR = 0.0;

   g_TradeManagement.breakEvenDone = false;
   g_TradeManagement.lockR1Done = false;
   g_TradeManagement.lockR15Done = false;
   g_TradeManagement.lockR2Done = false;


   Print(
      "TradeManager initialized | ",
      "Ticket=",
      ticket,
      " | Direction=",
      direction == BIAS_BULLISH ? "BUY" : "SELL",
      " | Entry=",
      entry,
      " | SL=",
      sl,
      " | TP=",
      g_TradeManagement.takeProfit,
      " | Risk=",
      risk
   );

   return true;
}


//+------------------------------------------------------------------+
//| Modify Position Stops                                            |
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


   if(newTP > 0.0 &&
      !IsValidTPForDirection(
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
         "TradeManager: PositionModify failed | ",
         "Ticket=",
         ticket,
         " | Retcode=",
         g_Trade.ResultRetcode(),
         " | ",
         g_Trade.ResultRetcodeDescription()
      );

      return false;
   }


   uint retcode =
      g_Trade.ResultRetcode();


   if(retcode != TRADE_RETCODE_DONE &&
      retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print(
         "TradeManager: SL modification rejected | ",
         "Retcode=",
         retcode,
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
      "TradeManager: R0.5 reached -> SL moved to BE | ",
      "Ticket=",
      g_TradeManagement.ticket
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
      "TradeManager: R1.5 reached -> SL moved to R1 | ",
      "Ticket=",
      g_TradeManagement.ticket
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
      "TradeManager: R2.0 reached -> SL moved to R1.5 | ",
      "Ticket=",
      g_TradeManagement.ticket
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
      "TradeManager: R2.5 reached -> SL moved to R2 | ",
      "Ticket=",
      g_TradeManagement.ticket
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
//| Detect And Initialize Existing EA Position                       |
//+------------------------------------------------------------------+

bool DetectAndInitializeTrade()
{
   ulong ticket =
      FindEAPositionTicket();


   if(ticket == 0)
      return false;


   if(g_TradeManagement.active &&
      g_TradeManagement.ticket == ticket)
   {
      return true;
   }


   return InitializeTradeManagement(
      ticket
   );
}


//+------------------------------------------------------------------+
//| Main Trade Management                                            |
//+------------------------------------------------------------------+

void UpdateTradeManagement()
{
   if(!g_TradeManagement.active)
   {
      if(!DetectAndInitializeTrade())
         return;
   }


   ManageActiveTrade();
}


//+------------------------------------------------------------------+
//| Check Active                                                     |
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
//| Get Current SL                                                   |
//+------------------------------------------------------------------+

double GetManagedTradeSL()
{
   if(!g_TradeManagement.active)
      return 0.0;

   return g_TradeManagement.currentSL;
}


//+------------------------------------------------------------------+
//| Get TP                                                           |
//+------------------------------------------------------------------+

double GetManagedTradeTP()
{
   if(!g_TradeManagement.active)
      return 0.0;

   return g_TradeManagement.takeProfit;
}


//+------------------------------------------------------------------+
//| Get Entry                                                        |
//+------------------------------------------------------------------+

double GetManagedTradeEntry()
{
   if(!g_TradeManagement.active)
      return 0.0;

   return g_TradeManagement.entryPrice;
}


//+------------------------------------------------------------------+
//| Get Ticket                                                        |
//+------------------------------------------------------------------+

ulong GetManagedTradeTicket()
{
   if(!g_TradeManagement.active)
      return 0;

   return g_TradeManagement.ticket;
}


//+------------------------------------------------------------------+
//| Cleanup After Position Closes                                    |
//+------------------------------------------------------------------+

void CleanupTradeManagement()
{
   if(!g_TradeManagement.active)
      return;


   if(IsEAPositionByTicket(
         g_TradeManagement.ticket
      ))
   {
      return;
   }


   Print(
      "TradeManager: Position closed | ",
      "Ticket=",
      g_TradeManagement.ticket,
      " | Final R=",
      DoubleToString(
         g_TradeManagement.currentR,
         2
      )
   );


   ResetTradeManagement();
}


//+------------------------------------------------------------------+

#endif


#ifndef SCALPINGEA_EXECUTION_ENGINE_MQH
#define SCALPINGEA_EXECUTION_ENGINE_MQH

#include "Constants.mqh"
#include "Structures.mqh"
#include "TradeManager.mqh"

//+------------------------------------------------------------------+
//| Execution Settings                                               |
//+------------------------------------------------------------------+

input group "=== Trade Execution ==="

input bool   InpEnableTrading    = true;
input bool   InpOnePositionOnly  = true;

input double InpFixedLotSize     = 0.01;
input bool   InpUseRiskBasedLot  = false;
input double InpRiskPercent      = 1.0;

input int    InpMaxSpreadPoints  = 100;
input int    InpSlippagePoints   = 30;

input ulong  InpMagicNumber      = 26080801;


//+------------------------------------------------------------------+
//| Execution State                                                  |
//+------------------------------------------------------------------+

struct ExecutionState
{
   bool valid;
   bool executed;

   double lotSize;

   double entryPrice;
   double stopLoss;
   double takeProfit;

   ulong positionTicket;

   datetime executionTime;

   string errorMessage;
};

ExecutionState g_Execution;


//+------------------------------------------------------------------+
//| Find Executed EA Position                                       |
//+------------------------------------------------------------------+

ulong FindExecutedPositionTicket()
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

      if(PositionGetString(
            POSITION_SYMBOL
         ) != _Symbol)
      {
         continue;
      }

      ulong magic =
         (ulong)PositionGetInteger(
            POSITION_MAGIC
         );

      if(magic != InpMagicNumber)
         continue;

      return ticket;
   }

   return 0;
}



//+------------------------------------------------------------------+
//| Reset                                                            |
//+------------------------------------------------------------------+

void ResetExecutionState()
{
   ZeroMemory(g_Execution);

   g_Execution.valid    = false;
   g_Execution.executed = false;
}


//+------------------------------------------------------------------+
//| Trading Allowed                                                  |
//+------------------------------------------------------------------+


bool IsTradingAllowed()
{
   if(!InpEnableTrading)
      return false;

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;

   long tradeMode =
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE
      );

   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+

void InitializeExecutionEngine()
{
   g_Trade.SetExpertMagicNumber(InpMagicNumber);

   g_Trade.SetDeviationInPoints(InpSlippagePoints);

   g_Trade.SetTypeFillingBySymbol(_Symbol);

   ResetExecutionState();
}


//+------------------------------------------------------------------+
//| Spread                                                           |
//+------------------------------------------------------------------+

bool IsSpreadAcceptable()
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

   if(bid <= 0.0 ||
      ask <= 0.0 ||
      point <= 0.0)
   {
      return false;
   }

   double spreadPoints =
      (ask - bid) / point;

   return spreadPoints <= InpMaxSpreadPoints;
}


//+------------------------------------------------------------------+
//| Existing EA position                                             |
//+------------------------------------------------------------------+

bool HasOpenPosition()
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
         (ulong)
         PositionGetInteger(POSITION_MAGIC);

      if(magic != InpMagicNumber)
         continue;

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Normalize lot                                                    |
//+------------------------------------------------------------------+

double NormalizeLotSize(double lotSize)
{
   double minimum =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MIN
      );

   double maximum =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MAX
      );

   double step =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_STEP
      );

   if(minimum <= 0.0 ||
      maximum <= 0.0 ||
      step <= 0.0)
   {
      return 0.0;
   }

   lotSize =
      MathMax(
         minimum,
         lotSize
      );

   lotSize =
      MathMin(
         maximum,
         lotSize
      );

   lotSize =
      MathFloor(
         lotSize / step
      ) * step;

   int digits = 2;

   if(step < 0.1)
      digits = 2;

   if(step < 0.01)
      digits = 3;

   if(step < 0.001)
      digits = 4;

   return NormalizeDouble(
      lotSize,
      digits
   );
}


//+------------------------------------------------------------------+
//| Risk based lot                                                   |
//+------------------------------------------------------------------+

double CalculateRiskBasedLot(
   double entryPrice,
   double stopLoss
)
{
   double balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );

   if(balance <= 0.0)
      return 0.0;

   double riskMoney =
      balance *
      InpRiskPercent /
      100.0;

   double tickSize =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_SIZE
      );

   double tickValue =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_VALUE
      );

   double priceRisk =
      MathAbs(
         entryPrice -
         stopLoss
      );

   if(riskMoney <= 0.0 ||
      tickSize <= 0.0 ||
      tickValue <= 0.0 ||
      priceRisk <= 0.0)
   {
      return 0.0;
   }

   double ticks =
      priceRisk /
      tickSize;

   double lossPerLot =
      ticks *
      tickValue;

   if(lossPerLot <= 0.0)
      return 0.0;

   double lotSize =
      riskMoney /
      lossPerLot;

   return NormalizeLotSize(
      lotSize
   );
}


//+------------------------------------------------------------------+
//| Calculate lot                                                    |
//+------------------------------------------------------------------+

double CalculateExecutionLot(
   double entryPrice,
   double stopLoss
)
{
   if(InpUseRiskBasedLot)
   {
      return CalculateRiskBasedLot(
         entryPrice,
         stopLoss
      );
   }

   return NormalizeLotSize(
      InpFixedLotSize
   );
}


//+------------------------------------------------------------------+
//| Normalize price                                                  |
//+------------------------------------------------------------------+

double NormalizeExecutionPrice(
   double price
)
{
   int digits =
      (int)
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS
      );

   return NormalizeDouble(
      price,
      digits
   );
}


//+------------------------------------------------------------------+
//| Validate BUY prices                                              |
//+------------------------------------------------------------------+

bool ValidateBuyPrices(
   double stopLoss,
   double takeProfit
)
{
   double ask =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_ASK
      );

   if(ask <= 0.0)
      return false;

   if(stopLoss >= ask)
      return false;

   if(takeProfit <= ask)
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| Validate SELL prices                                             |
//+------------------------------------------------------------------+

bool ValidateSellPrices(
   double stopLoss,
   double takeProfit
)
{
   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID
      );

   if(bid <= 0.0)
      return false;

   if(stopLoss <= bid)
      return false;

   if(takeProfit >= bid)
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| Broker stop validation                                           |
//+------------------------------------------------------------------+

bool ValidateBrokerStops(
   ENUM_BIAS direction,
   double stopLoss,
   double takeProfit
)
{
   double point =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT
      );

   if(point <= 0.0)
      return false;

   long stopsLevel =
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      );

   double minimumDistance =
      stopsLevel * point;

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

   //===============================================================
   // BUY
   //===============================================================

   if(direction == BIAS_BULLISH)
   {
      if((ask - stopLoss) < minimumDistance)
         return false;

      if((takeProfit - ask) < minimumDistance)
         return false;

      return true;
   }

   //===============================================================
   // SELL
   //===============================================================

   if(direction == BIAS_BEARISH)
   {
      if((stopLoss - bid) < minimumDistance)
         return false;

      if((bid - takeProfit) < minimumDistance)
         return false;

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| Prepare BUY                                                      |
//+------------------------------------------------------------------+

bool PrepareBuyExecution(
   double stopLoss,
   double takeProfit
)
{
   ResetExecutionState();

   if(!IsTradingAllowed())
   {
      g_Execution.errorMessage =
         "Trading is not allowed.";

      return false;
   }

   if(InpOnePositionOnly &&
      HasOpenPosition())
   {
      g_Execution.errorMessage =
         "Existing EA position.";

      return false;
   }

   if(!IsSpreadAcceptable())
   {
      g_Execution.errorMessage =
         "Spread too high.";

      return false;
   }

   double ask =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_ASK
      );

   if(!ValidateBuyPrices(
      stopLoss,
      takeProfit
   ))
   {
      g_Execution.errorMessage =
         "Invalid BUY SL/TP.";

      return false;
   }

   if(!ValidateBrokerStops(
      BIAS_BULLISH,
      stopLoss,
      takeProfit
   ))
   {
      g_Execution.errorMessage =
         "BUY SL/TP violates broker stops.";

      return false;
   }

   double lotSize =
      CalculateExecutionLot(
         ask,
         stopLoss
      );

   if(lotSize <= 0.0)
   {
      g_Execution.errorMessage =
         "Invalid lot size.";

      return false;
   }

   g_Execution.valid =
      true;

   g_Execution.lotSize =
      lotSize;

   g_Execution.entryPrice =
      NormalizeExecutionPrice(
         ask
      );

   g_Execution.stopLoss =
      NormalizeExecutionPrice(
         stopLoss
      );

   g_Execution.takeProfit =
      NormalizeExecutionPrice(
         takeProfit
      );

   return true;
}


//+------------------------------------------------------------------+
//| Prepare SELL                                                     |
//+------------------------------------------------------------------+

bool PrepareSellExecution(
   double stopLoss,
   double takeProfit
)
{
   ResetExecutionState();

   if(!IsTradingAllowed())
   {
      g_Execution.errorMessage =
         "Trading is not allowed.";

      return false;
   }

   if(InpOnePositionOnly &&
      HasOpenPosition())
   {
      g_Execution.errorMessage =
         "Existing EA position.";

      return false;
   }

   if(!IsSpreadAcceptable())
   {
      g_Execution.errorMessage =
         "Spread too high.";

      return false;
   }

   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID
      );

   if(!ValidateSellPrices(
      stopLoss,
      takeProfit
   ))
   {
      g_Execution.errorMessage =
         "Invalid SELL SL/TP.";

      return false;
   }

   if(!ValidateBrokerStops(
      BIAS_BEARISH,
      stopLoss,
      takeProfit
   ))
   {
      g_Execution.errorMessage =
         "SELL SL/TP violates broker stops.";

      return false;
   }

   double lotSize =
      CalculateExecutionLot(
         bid,
         stopLoss
      );

   if(lotSize <= 0.0)
   {
      g_Execution.errorMessage =
         "Invalid lot size.";

      return false;
   }

   g_Execution.valid =
      true;

   g_Execution.lotSize =
      lotSize;

   g_Execution.entryPrice =
      NormalizeExecutionPrice(
         bid
      );

   g_Execution.stopLoss =
      NormalizeExecutionPrice(
         stopLoss
      );

   g_Execution.takeProfit =
      NormalizeExecutionPrice(
         takeProfit
      );

   return true;
}


//+------------------------------------------------------------------+
//| Execute BUY                                                      |
//+------------------------------------------------------------------+

bool ExecuteBuy(
   double stopLoss,
   double takeProfit
)
{
   if(!PrepareBuyExecution(
      stopLoss,
      takeProfit
   ))
   {
      return false;
   }

   bool result =
      g_Trade.Buy(
         g_Execution.lotSize,
         _Symbol,
         0.0,
         g_Execution.stopLoss,
         g_Execution.takeProfit,
         "ScalpingEA BUY"
      );

   if(!result)
   {
      g_Execution.errorMessage =
         g_Trade.ResultRetcodeDescription();

      return false;
   }

   g_Execution.executed =
      true;

   g_Execution.executionTime =
      TimeCurrent();

g_Execution.positionTicket =
   FindExecutedPositionTicket();
   
   return true;
}


//+------------------------------------------------------------------+
//| Execute SELL                                                     |
//+------------------------------------------------------------------+

bool ExecuteSell(
   double stopLoss,
   double takeProfit
)
{
   if(!PrepareSellExecution(
      stopLoss,
      takeProfit
   ))
   {
      return false;
   }

   bool result =
      g_Trade.Sell(
         g_Execution.lotSize,
         _Symbol,
         0.0,
         g_Execution.stopLoss,
         g_Execution.takeProfit,
         "ScalpingEA SELL"
      );

   if(!result)
   {
      g_Execution.errorMessage =
         g_Trade.ResultRetcodeDescription();

      return false;
   }

   g_Execution.executed =
      true;

   g_Execution.executionTime =
      TimeCurrent();

g_Execution.positionTicket =
   FindExecutedPositionTicket();

   return true;
}


//+------------------------------------------------------------------+
//| Execute validated direction                                      |
//+------------------------------------------------------------------+
//
// Direction is supplied by the already validated setup.
// Execution does NOT determine bias or setup direction.
//

bool ExecuteValidatedTrade(
   ENUM_BIAS direction,
   double stopLoss,
   double takeProfit
)
{
   if(direction == BIAS_BULLISH)
   {
      return ExecuteBuy(
         stopLoss,
         takeProfit
      );
   }

   if(direction == BIAS_BEARISH)
   {
      return ExecuteSell(
         stopLoss,
         takeProfit
      );
   }

   g_Execution.errorMessage =
      "Invalid setup direction.";

   return false;
}


//+------------------------------------------------------------------+

#endif


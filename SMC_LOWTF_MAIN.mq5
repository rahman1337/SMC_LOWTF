//+------------------------------------------------------------------+
//| SMC_LOWTF_MAIN.mq5                                               |
//| Main EA: Liquidity -> Structure -> OrderBlock -> Entry ->        |
//|          Trade Manager -> Execution                              |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "SMC Low-TF main EA pipeline"

// Core modules. Include guards inside the modules prevent duplicates.
#include "Constants.mqh"
#include "Structures.mqh"
#include "LiquiditySweepEngine.mqh"
#include "StructureEngine.mqh"
#include "OrderBlockEngine.mqh"
#include "EntryEngine.mqh"
#include "TradeManager.mqh"
#include "ExecutionEngine.mqh"
#include "Dashboard.mqh"
#include "ChartDrawing.mqh"

//+------------------------------------------------------------------+
//| Main EA settings                                                  |
//+------------------------------------------------------------------+
input group "=== MAIN EA ==="

input bool InpMainEAEnabled       = true;
input bool InpScanOnNewM1Bar      = true;
input bool InpDrawMainEAObjects   = true;
input bool InpUseSetupLock        = true;
input int  InpSetupLockMaxBars    = 100;

//+------------------------------------------------------------------+
//| Main pipeline state                                               |
//+------------------------------------------------------------------+
struct MainSetupLock
{
   bool     active;
   bool     traded;
   ENUM_BIAS direction;
   datetime liquidityTime;
   datetime structureTime;
   datetime obTime;
   datetime entryTime;
};

MainSetupLock g_MainLock;

datetime g_LastM1Bar = 0;

//+------------------------------------------------------------------+
//| Reset main state                                                  |
//+------------------------------------------------------------------+
void ResetMainState()
{
   ZeroMemory(g_MainLock);
   g_MainLock.active = false;
   g_MainLock.traded = false;
   g_MainLock.direction = BIAS_NONE;

   g_LastM1Bar = 0;

   ResetLiquidityEnvironment();
   ResetStructureState();
   ResetEntryState();
   ResetExecutionState();
   ResetTradeManagement();
}

//+------------------------------------------------------------------+
//| Detect a new M1 bar                                               |
//+------------------------------------------------------------------+
bool IsNewM1Bar()
{
   datetime currentBar = iTime(_Symbol, PERIOD_M1, 0);

   if(currentBar <= 0)
      return false;

   if(g_LastM1Bar == 0)
   {
      g_LastM1Bar = currentBar;
      return true;
   }

   if(currentBar != g_LastM1Bar)
   {
      g_LastM1Bar = currentBar;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Setup identity                                                    |
//| A setup is identified by direction + liquidity + structure + OB. |
//| This prevents the EA from repeatedly entering the same setup.    |
//+------------------------------------------------------------------+
bool IsSameSetup(
   ENUM_BIAS direction,
   datetime liquidityTime,
   datetime structureTime,
   datetime obTime
)
{
   if(!InpUseSetupLock || !g_MainLock.active)
      return false;

   return
      g_MainLock.direction     == direction &&
      g_MainLock.liquidityTime == liquidityTime &&
      g_MainLock.structureTime == structureTime &&
      g_MainLock.obTime        == obTime;
}

//+------------------------------------------------------------------+
//| Save setup identity                                               |
//+------------------------------------------------------------------+
void LockSetup(
   ENUM_BIAS direction,
   datetime liquidityTime,
   datetime structureTime,
   datetime obTime,
   datetime entryTime
)
{
   g_MainLock.active         = true;
   g_MainLock.traded         = false;
   g_MainLock.direction      = direction;
   g_MainLock.liquidityTime  = liquidityTime;
   g_MainLock.structureTime  = structureTime;
   g_MainLock.obTime         = obTime;
   g_MainLock.entryTime      = entryTime;
}

//+------------------------------------------------------------------+
//| Expire old setup lock                                             |
//+------------------------------------------------------------------+
void ExpireSetupLock()
{
   if(!g_MainLock.active)
      return;

   datetime now = TimeCurrent();

   datetime anchor = g_MainLock.entryTime;
   if(anchor <= 0)
      anchor = g_MainLock.obTime;
   if(anchor <= 0)
      anchor = g_MainLock.structureTime;
   if(anchor <= 0)
      anchor = g_MainLock.liquidityTime;

   if(anchor <= 0)
      return;

   int shift = iBarShift(
      _Symbol,
      PERIOD_M1,
      anchor,
      false
   );

   if(shift >= InpSetupLockMaxBars)
   {
      g_MainLock.active = false;
      g_MainLock.traded = false;
   }

   // Absolute time fallback for unusual history gaps.
   if((now - anchor) > (InpSetupLockMaxBars * 60))
   {
      g_MainLock.active = false;
      g_MainLock.traded = false;
   }
}

//+------------------------------------------------------------------+
//| Run the complete setup pipeline                                  |
//+------------------------------------------------------------------+
void RunSetupPipeline()
{
   if(!InpMainEAEnabled)
      return;

   //===============================================================
   // 1. LIQUIDITY
   //===============================================================
   ScanLiquidity();

   if(!g_Liquidity.valid)
      return;

   ENUM_BIAS direction = g_Liquidity.direction;

   if(direction != BIAS_BULLISH &&
      direction != BIAS_BEARISH)
   {
      return;
   }

   //===============================================================
   // 2. STRUCTURE ENGINE
   //===============================================================
   ResetStructureState();

   ScanM5Structure(
      direction,
      g_Liquidity,
      g_Structure
   );

   if(!g_Structure.valid)
      return;

   //===============================================================
   // 3. ORDER BLOCK ENGINE
   //===============================================================
   ResetEntryState();

   ScanOrderBlock(
      direction,
   g_Liquidity.direction,
   g_Liquidity,
   g_Structure,
   g_OrderBlock
);

   if(!g_OrderBlock.valid)
      return;

   if(!HasValidOrderBlock())
      return;

   //===============================================================
   // Setup lock is checked after OB because the OB is part of the
   // unique setup identity.
   //===============================================================
   if(IsSameSetup(
         direction,
         g_Liquidity.sweepTime,
         g_Structure.confirmationTime,
         g_OrderBlock.createdTime
      ))
   {
      return;
   }

   //===============================================================
   // 4. ENTRY ENGINE
   //===============================================================
   ScanEntryConfirmation(
      g_OrderBlock,
      g_Entry
   );

   if(!g_Entry.valid)
      return;

   //===============================================================
   // Lock before sending the order. This prevents duplicate orders
   // if the terminal receives multiple ticks around execution.
   //===============================================================
   LockSetup(
      direction,
      g_Liquidity.sweepTime,
      g_Structure.confirmationTime,
      g_OrderBlock.createdTime,
      g_Entry.confirmationTime
   );

   //===============================================================
   // 5. EXECUTION ENGINE
   //===============================================================
   if(!InpEnableTrading)
      return;

   if(!ExecuteValidatedTrade(
         direction,
         g_Entry.stopLoss,
         g_Entry.takeProfit
      ))
   {
      // The setup remains locked for this setup identity, but it is
      // not marked traded. A later fresh setup can still trade.
      g_MainLock.traded = false;
      return;
   }

   g_MainLock.traded = true;

   //===============================================================
   // 6. TRADE MANAGER
   //===============================================================
   ulong ticket = g_Execution.positionTicket;

   if(ticket > 0 &&
      PositionSelectByTicket(ticket))
   {
      double actualEntry =
         PositionGetDouble(POSITION_PRICE_OPEN);

      double actualSL =
         PositionGetDouble(POSITION_SL);

      if(actualSL <= 0.0)
         actualSL = g_Entry.stopLoss;

      InitializeTradeManagement(
         ticket,
         direction,
         actualEntry,
         actualSL
      );
   }
}

//+------------------------------------------------------------------+
//| Update management and UI                                          |
//+------------------------------------------------------------------+
void UpdateEA()
{
   // Trade management MUST run on every tick. Do not put this
   // behind the new-bar filter; trailing/BE/lock logic needs ticks.
   UpdateTradeManagement();
   CleanupTradeManagement();

   if(InpShowDashboard)
      UpdateDashboard();

   if(InpDrawMainEAObjects)
      UpdateChartDrawings();

   ExpireSetupLock();
}

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   ResetMainState();

   InitializeExecutionEngine();

   InitializeDashboard();
   InitializeChartDrawing();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ShutdownDashboard();
   ReleaseChartDrawing();

   ResetTradeManagement();
}

//+------------------------------------------------------------------+
//| Expert tick                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpMainEAEnabled)
   {
      UpdateEA();
      return;
   }

   // Management/UI are always live.
   UpdateEA();

   // Setup detection is intentionally throttled to M1 bar opens.
   // This keeps the engine from opening repeated trades on every tick
   // while still allowing M1 confirmation to be processed promptly.
   bool runScan = true;

   if(InpScanOnNewM1Bar)
      runScan = IsNewM1Bar();

   if(!runScan)
      return;

   // Never create a second EA position when one is already active.
   if(InpOnePositionOnly && HasOpenPosition())
      return;

   RunSetupPipeline();
   
   
}

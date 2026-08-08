//+------------------------------------------------------------------+
//| SMC_LOWTF_MAIN.mq5                                               |
//|                                                                  |
//| Main EA Pipeline:                                                |
//| Liquidity -> Structure -> Order Block -> Entry -> Execution      |
//| -> Trade Manager -> Dashboard -> Chart Drawing                  |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "SMC Low-TF main EA pipeline"

//+------------------------------------------------------------------+
//| CORE MODULES                                                     |
//+------------------------------------------------------------------+

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
//| MAIN EA SETTINGS                                                 |
//+------------------------------------------------------------------+

input group "=== MAIN EA ==="

input bool InpMainEAEnabled       = true;
input bool InpScanOnNewM1Bar      = true;

input bool InpDrawMainEAObjects   = true;

input bool InpUseSetupLock        = true;
input int  InpSetupLockMaxBars    = 100;


//+------------------------------------------------------------------+
//| MAIN SETUP LOCK                                                  |
//+------------------------------------------------------------------+

struct MainSetupLock
{
   bool       active;
   bool       traded;

   ENUM_BIAS  direction;

   datetime   liquidityTime;
   datetime   structureTime;
   datetime   obTime;
   datetime   entryTime;
};


//+------------------------------------------------------------------+
//| GLOBAL MAIN STATE                                                |
//+------------------------------------------------------------------+

MainSetupLock g_MainLock;

datetime g_LastM1Bar = 0;


//+------------------------------------------------------------------+
//| RESET MAIN STATE                                                 |
//+------------------------------------------------------------------+

void ResetMainState()
{
   ZeroMemory(g_MainLock);

   g_MainLock.active    = false;
   g_MainLock.traded    = false;
   g_MainLock.direction = BIAS_NONE;

   g_LastM1Bar = 0;

   // Reset all engine states.
   ResetLiquidityEnvironment();
   ResetStructureState();
   ResetEntryState();
   ResetExecutionState();
   ResetTradeManagement();
}


//+------------------------------------------------------------------+
//| NEW M1 BAR DETECTION                                             |
//+------------------------------------------------------------------+

bool IsNewM1Bar()
{
   datetime currentBar =
      iTime(
         _Symbol,
         PERIOD_M1,
         0
      );

   if(currentBar <= 0)
      return false;


   // First initialization.
   if(g_LastM1Bar == 0)
   {
      g_LastM1Bar = currentBar;

      return true;
   }


   // New M1 candle.
   if(currentBar != g_LastM1Bar)
   {
      g_LastM1Bar = currentBar;

      return true;
   }


   return false;
}


//+------------------------------------------------------------------+
//| CHECK WHETHER SETUP IS THE SAME                                  |
//+------------------------------------------------------------------+
//
// Setup identity:
// direction
// +
// liquidity sweep
// +
// structure confirmation
// +
// order block creation
//
// This prevents the same setup from generating another entry.
//

bool IsSameSetup(
   ENUM_BIAS direction,
   datetime liquidityTime,
   datetime structureTime,
   datetime obTime
)
{
   if(!InpUseSetupLock)
      return false;

   if(!g_MainLock.active)
      return false;


   if(g_MainLock.direction != direction)
      return false;

   if(g_MainLock.liquidityTime != liquidityTime)
      return false;

   if(g_MainLock.structureTime != structureTime)
      return false;

   if(g_MainLock.obTime != obTime)
      return false;


   return true;
}


//+------------------------------------------------------------------+
//| LOCK CURRENT SETUP                                               |
//+------------------------------------------------------------------+

void LockSetup(
   ENUM_BIAS direction,
   datetime liquidityTime,
   datetime structureTime,
   datetime obTime,
   datetime entryTime
)
{
   g_MainLock.active        = true;
   g_MainLock.traded        = false;

   g_MainLock.direction     = direction;

   g_MainLock.liquidityTime = liquidityTime;
   g_MainLock.structureTime = structureTime;
   g_MainLock.obTime        = obTime;
   g_MainLock.entryTime     = entryTime;
}


//+------------------------------------------------------------------+
//| EXPIRE OLD SETUP LOCK                                            |
//+------------------------------------------------------------------+

void ExpireSetupLock()
{
   if(!InpUseSetupLock)
      return;

   if(!g_MainLock.active)
      return;


   datetime now =
      TimeCurrent();


   //===============================================================
   // Find best setup anchor.
   //===============================================================

   datetime anchor =
      g_MainLock.entryTime;


   if(anchor <= 0)
      anchor = g_MainLock.obTime;

   if(anchor <= 0)
      anchor = g_MainLock.structureTime;

   if(anchor <= 0)
      anchor = g_MainLock.liquidityTime;


   if(anchor <= 0)
      return;


   //===============================================================
   // M1 BAR AGE
   //===============================================================

   int shift =
      iBarShift(
         _Symbol,
         PERIOD_M1,
         anchor,
         false
      );


   if(shift >= InpSetupLockMaxBars)
   {
      g_MainLock.active = false;
      g_MainLock.traded = false;

      return;
   }


   //===============================================================
   // ABSOLUTE TIME FALLBACK
   //===============================================================

   int maxSeconds =
      InpSetupLockMaxBars * 60;


   if((now - anchor) > maxSeconds)
   {
      g_MainLock.active = false;
      g_MainLock.traded = false;

      return;
   }
}


//+------------------------------------------------------------------+
//| RUN COMPLETE SETUP PIPELINE                                      |
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


   ENUM_BIAS direction =
      g_Liquidity.direction;


   if(direction != BIAS_BULLISH &&
      direction != BIAS_BEARISH)
   {
      return;
   }


   //===============================================================
   // 2. M5 STRUCTURE
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
   // 3. ORDER BLOCK
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
   // SETUP LOCK
   //===============================================================
   //
   // The setup is checked only after the OB exists because:
   //
   // Liquidity + Structure + OB
   //
   // together define the setup identity.
   //

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
   // 4. ENTRY CONFIRMATION
   //===============================================================

   ScanEntryConfirmation(
      g_OrderBlock,
      g_Entry
   );


   if(!g_Entry.valid)
      return;


   //===============================================================
   // LOCK SETUP BEFORE EXECUTION
   //===============================================================
   //
   // Lock BEFORE sending the order.
   //
   // This protects against multiple ticks or execution callbacks
   // causing the same setup to fire more than once.
   //

   LockSetup(
      direction,
      g_Liquidity.sweepTime,
      g_Structure.confirmationTime,
      g_OrderBlock.createdTime,
      g_Entry.confirmationTime
   );


   //===============================================================
   // 5. EXECUTION
   //===============================================================

   if(!InpEnableTrading)
      return;


   bool executionResult =
      ExecuteValidatedTrade(
         direction,
         g_Entry.stopLoss,
         g_Entry.takeProfit
      );


   //===============================================================
   // EXECUTION FAILED
   //===============================================================

   if(!executionResult)
   {
      g_MainLock.traded = false;

      return;
   }


   //===============================================================
   // EXECUTION SUCCESS
   //===============================================================

   g_MainLock.traded = true;


   //===============================================================
   // 6. INITIALIZE TRADE MANAGER
   //===============================================================

   ulong ticket =
      g_Execution.positionTicket;


   if(ticket <= 0)
      return;


   if(!PositionSelectByTicket(ticket))
      return;


   double actualEntry =
      PositionGetDouble(
         POSITION_PRICE_OPEN
      );


   double actualSL =
      PositionGetDouble(
         POSITION_SL
      );


   // If broker/execution did not return SL,
   // fall back to validated entry SL.
   if(actualSL <= 0.0)
      actualSL = g_Entry.stopLoss;


   InitializeTradeManagement(
      ticket,
      direction,
      actualEntry,
      actualSL
   );
}


//+------------------------------------------------------------------+
//| UPDATE LIVE EA STATE                                             |
//+------------------------------------------------------------------+
//
// This function runs EVERY TICK.
//
// Important:
// Trade management must NEVER be restricted to the M1 new-bar
// condition because BE, trailing, protection and exit management
// require live tick updates.
//

void UpdateEA()
{
   //===============================================================
   // TRADE MANAGEMENT
   //===============================================================

   UpdateTradeManagement();

   CleanupTradeManagement();


   //===============================================================
   // DASHBOARD
   //===============================================================

   if(InpShowDashboard)
      UpdateDashboard();


   //===============================================================
   // CHART DRAWING
   //===============================================================

   if(InpDrawMainEAObjects)
      UpdateChartDrawings();


   //===============================================================
   // SETUP LOCK EXPIRATION
   //===============================================================

   ExpireSetupLock();
}


//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+

int OnInit()
{
   //===============================================================
   // RESET ALL STATE
   //===============================================================

   ResetMainState();


   //===============================================================
   // EXECUTION ENGINE
   //===============================================================

   InitializeExecutionEngine();


   //===============================================================
   // DASHBOARD
   //===============================================================

   InitializeDashboard();


   //===============================================================
   // CHART DRAWING
   //===============================================================

   InitializeChartDrawing();


   //===============================================================
   // INITIAL M1 BAR
   //===============================================================

   g_LastM1Bar =
      iTime(
         _Symbol,
         PERIOD_M1,
         0
      );


   return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+

void OnDeinit(
   const int reason
)
{
   //===============================================================
   // DASHBOARD
   //===============================================================

   ShutdownDashboard();


   //===============================================================
   // CHART DRAWING
   //===============================================================

   ReleaseChartDrawing();


   //===============================================================
   // TRADE MANAGEMENT
   //===============================================================

   ResetTradeManagement();
}


//+------------------------------------------------------------------+
//| EXPERT TICK                                                      |
//+------------------------------------------------------------------+

void OnTick()
{
   //===============================================================
   // LIVE MANAGEMENT/UI
   //===============================================================
   //
   // This ALWAYS runs first.
   //
   // Even when the setup scanner is disabled or waiting for a new
   // M1 candle, existing trades continue to be managed.
   //

   UpdateEA();


   //===============================================================
   // MAIN EA DISABLED
   //===============================================================

   if(!InpMainEAEnabled)
      return;


   //===============================================================
   // NEW M1 BAR FILTER
   //===============================================================

   bool runScan = true;


   if(InpScanOnNewM1Bar)
      runScan = IsNewM1Bar();


   if(!runScan)
      return;


   //===============================================================
   // ONLY ONE EA POSITION
   //===============================================================
   //
   // Never allow a second position while the current EA position
   // is still active.
   //

   if(InpOnePositionOnly &&
      HasOpenPosition())
   {
      return;
   }


   //===============================================================
   // RUN SETUP PIPELINE
   //===============================================================

   RunSetupPipeline();
}


//+------------------------------------------------------------------+

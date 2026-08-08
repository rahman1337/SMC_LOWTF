#ifndef __SMC_LOWTF_DASHBOARD_MQH__
#define __SMC_LOWTF_DASHBOARD_MQH__

#include "Constants.mqh"
#include "Structures.mqh"
#include "StructureEngine.mqh"
#include "OrderBlockEngine.mqh"
#include "EntryEngine.mqh"
#include "ExecutionEngine.mqh"

//+------------------------------------------------------------------+
//| SMC LOW-TF DASHBOARD                                             |
//| LABEL ONLY - NO BACKGROUND RECTANGLE                             |
//+------------------------------------------------------------------+

input group "=== Dashboard ==="

input bool InpShowDashboard       = true;
input int  InpDashboardX          = 20;
input int InpDashboardY          = 30;
input int InpDashboardTextSize    = 9;
input int InpDashboardLineHeight  = 17;


//+------------------------------------------------------------------+
//| COLORS                                                           |
//+------------------------------------------------------------------+

color DashHeader  = clrGold;
color DashText    = clrWhite;
color DashBuy     = clrLime;
color DashSell    = clrRed;
color DashNeutral = clrGray;
color DashOrange  = clrOrange;


//+------------------------------------------------------------------+
//| PREFIX                                                           |
//+------------------------------------------------------------------+

string DASH_PREFIX = "SMC_LOWTF_MAIN_";


//+------------------------------------------------------------------+
//| OBJECT NAME                                                      |
//+------------------------------------------------------------------+

string DashObjectName(string id)
{
   return DASH_PREFIX + id;
}


//+------------------------------------------------------------------+
//| DELETE OBJECTS BY PREFIX                                         |
//+------------------------------------------------------------------+

void DeleteObjectsWithPrefix(string prefix)
{
   int total = ObjectsTotal(0, -1, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);

      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}


//+------------------------------------------------------------------+
//| DELETE OLD DASHBOARD OBJECTS                                     |
//+------------------------------------------------------------------+

void DeleteDashboard()
{
   // Current dashboard
   DeleteObjectsWithPrefix(DASH_PREFIX);

   // Previous versions
   DeleteObjectsWithPrefix("SMC_LOWTF_DASH_");
   DeleteObjectsWithPrefix("ScalpingEA_Dash_");
   DeleteObjectsWithPrefix("SMC_Dash_");

   // Known old background objects
   ObjectDelete(0, "ScalpingEA_Dashboard_Background");
   ObjectDelete(0, "SMC_LOWTF_Dashboard_Background");

   // Extra possible old background names
   ObjectDelete(0, "SMC_LOWTF_MAIN_Background");
   ObjectDelete(0, "SMC_LOWTF_DASH_Panel");
   ObjectDelete(0, "SMC_LOWTF_DASH_Background");

   ChartRedraw(0);
}


//+------------------------------------------------------------------+
//| DRAW LABEL                                                       |
//+------------------------------------------------------------------+

void DrawDashboardLabel(
   string name,
   string text,
   int x,
   int y,
   int size,
   color clr,
   bool bold = false
)
{
   string objectName = DashObjectName(name);

   if(ObjectFind(0, objectName) < 0)
   {
      if(!ObjectCreate(
            0,
            objectName,
            OBJ_LABEL,
            0,
            0,
            0
         ))
      {
         return;
      }
   }

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_XDISTANCE,
      x
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_FONTSIZE,
      size
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_COLOR,
      clr
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_HIDDEN,
      true
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_ZORDER,
      100
   );

   ObjectSetString(
      0,
      objectName,
      OBJPROP_FONT,
      bold ? "Arial Bold" : "Arial"
   );

   ObjectSetString(
      0,
      objectName,
      OBJPROP_TEXT,
      text
   );
}


//+------------------------------------------------------------------+
//| POSITION DIRECTION                                               |
//+------------------------------------------------------------------+

string GetPositionDirection()
{
   if(!PositionSelect(_Symbol))
      return "NONE";

   ENUM_POSITION_TYPE type =
      (ENUM_POSITION_TYPE)
      PositionGetInteger(POSITION_TYPE);

   if(type == POSITION_TYPE_BUY)
      return "BUY";

   if(type == POSITION_TYPE_SELL)
      return "SELL";

   return "NONE";
}


//+------------------------------------------------------------------+
//| MANAGEMENT STATUS                                                |
//+------------------------------------------------------------------+

string GetTradeManagementStage()
{
   if(!PositionSelect(_Symbol))
      return "WAITING";

   double entry =
      PositionGetDouble(POSITION_PRICE_OPEN);

   double sl =
      PositionGetDouble(POSITION_SL);

   if(entry <= 0.0)
      return "ACTIVE";

   if(sl <= 0.0)
      return "ACTIVE";

   string direction =
      GetPositionDirection();

   if(direction == "BUY")
   {
      if(sl >= entry)
         return "BE / PROTECTED";

      return "SL ACTIVE";
   }

   if(direction == "SELL")
   {
      if(sl <= entry)
         return "BE / PROTECTED";

      return "SL ACTIVE";
   }

   return "ACTIVE";
}


//+------------------------------------------------------------------+
//| LIQUIDITY STATUS                                                 |
//+------------------------------------------------------------------+

string GetLiquidityStatus()
{
   if(!g_Liquidity.valid)
      return "WAITING";

   if(g_Liquidity.type == LIQUIDITY_SELL_SIDE)
      return "SELL-SIDE SWEPT";

   if(g_Liquidity.type == LIQUIDITY_BUY_SIDE)
      return "BUY-SIDE SWEPT";

   return "CONFIRMED";
}


//+------------------------------------------------------------------+
//| STRUCTURE STATUS                                                 |
//+------------------------------------------------------------------+

string GetStructureStatus()
{
   if(!g_Structure.valid)
      return "WAITING";

   string result = "";

   if(g_Structure.bos)
      result += "BOS ";

   if(g_Structure.choch)
      result += "CHOCH ";

   if(g_Structure.mss)
      result += "MSS ";

   if(g_Structure.ifvg)
      result += "IFVG ";

   if(result == "")
      return "CONFIRMED";

   return result;
}


//+------------------------------------------------------------------+
//| ORDER BLOCK STATUS                                               |
//+------------------------------------------------------------------+

string GetOBStatus()
{
   if(!g_OrderBlock.valid)
      return "WAITING";

   if(
      g_OrderBlock.fresh &&
      g_OrderBlock.unmitigated
   )
   {
      return "FRESH / UNMITIGATED";
   }

   return "INVALID";
}


//+------------------------------------------------------------------+
//| FVG STATUS                                                       |
//+------------------------------------------------------------------+

string GetFVGStatus()
{
   if(!g_OrderBlock.valid)
      return "WAITING";

   if(!g_OrderBlock.hasFVG)
      return "NONE";

   if(g_OrderBlock.fvgInsideOB)
      return "INSIDE OB";

   if(g_OrderBlock.fvgBesideOB)
      return "BESIDE OB";

   if(g_OrderBlock.fvgNearOB)
      return "NEAR OB";

   return "CONFIRMED";
}


//+------------------------------------------------------------------+
//| ENTRY STATUS                                                     |
//+------------------------------------------------------------------+

string GetEntryStatus()
{
   if(!g_Entry.valid)
      return "WAITING";

   if(g_Entry.m1Confirmation)
      return "M1 CONFIRMED";

   if(g_Entry.m5Confirmation)
      return "M5 CONFIRMED";

   if(g_Entry.zoneHeld)
      return "ZONE HELD";

   return "ZONE ACTIVE";
}


//+------------------------------------------------------------------+
//| CURRENT R                                                        |
//+------------------------------------------------------------------+

double GetCurrentR()
{
   if(!PositionSelect(_Symbol))
      return 0.0;

   double entry =
      PositionGetDouble(POSITION_PRICE_OPEN);

   double sl =
      PositionGetDouble(POSITION_SL);

   double current =
      PositionGetDouble(POSITION_PRICE_CURRENT);

   if(
      entry <= 0.0 ||
      sl <= 0.0
   )
   {
      return 0.0;
   }

   double risk =
      MathAbs(entry - sl);

   if(risk <= 0.0)
      return 0.0;

   string direction =
      GetPositionDirection();

   if(direction == "BUY")
      return (current - entry) / risk;

   if(direction == "SELL")
      return (entry - current) / risk;

   return 0.0;
}


//+------------------------------------------------------------------+
//| MAIN DASHBOARD                                                   |
//+------------------------------------------------------------------+

void UpdateDashboard()
{
   if(!InpShowDashboard)
      return;

   //===============================================================
   // POSITION
   //===============================================================

   bool hasPosition =
      PositionSelect(_Symbol);

   string direction =
      GetPositionDirection();

   //===============================================================
   // ACCOUNT
   //===============================================================

   double balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );

   double equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   double floatingPL =
      AccountInfoDouble(
         ACCOUNT_PROFIT
      );

   //===============================================================
   // STATUS
   //===============================================================

   string status =
      "WAITING";

   color statusColor =
      DashNeutral;

   if(g_Execution.executed && hasPosition)
   {
      status =
         "TRADE ACTIVE";

      statusColor =
         DashBuy;
   }
   else
   if(g_Entry.valid)
   {
      status =
         "ENTRY CONFIRMED";

      statusColor =
         DashBuy;
   }
   else
   if(g_OrderBlock.valid)
   {
      status =
         "OB CONFIRMED";

      statusColor =
         DashOrange;
   }
   else
   if(g_Structure.valid)
   {
      status =
         "STRUCTURE CONFIRMED";

      statusColor =
         DashOrange;
   }
   else
   if(g_Liquidity.valid)
   {
      status =
         "LIQUIDITY CONFIRMED";

      statusColor =
         DashOrange;
   }

   //===============================================================
   // POSITION COLOR
   //===============================================================

   color directionColor =
      DashNeutral;

   if(direction == "BUY")
      directionColor = DashBuy;
   else
   if(direction == "SELL")
      directionColor = DashSell;

   //===============================================================
   // P/L COLOR
   //===============================================================

   color pnlColor =
      DashNeutral;

   if(floatingPL > 0.0)
      pnlColor = DashBuy;
   else
   if(floatingPL < 0.0)
      pnlColor = DashSell;

   //===============================================================
   // START POSITION
   //===============================================================

   int startX =
      InpDashboardX;

   int currentY =
      InpDashboardY;

   int textsize =
      InpDashboardTextSize;

   int detailsSize =
      InpDashboardTextSize;

   int lineHeight =
      InpDashboardLineHeight;

   //===============================================================
   // HEADER
   //===============================================================

   DrawDashboardLabel(
      "Title",
      "SMC LOW-TF",
      startX,
      currentY,
      11,
      DashHeader,
      true
   );

   currentY +=
      lineHeight + 5;

   //===============================================================
   // STATUS
   //===============================================================

   DrawDashboardLabel(
      "Status",
      "Status: " + status,
      startX,
      currentY,
      textsize,
      statusColor,
      true
   );

   currentY += lineHeight;

   //===============================================================
   // BALANCE
   //===============================================================

   DrawDashboardLabel(
      "Balance",
      StringFormat(
         "Balance: $%.2f",
         balance
      ),
      startX,
      currentY,
      textsize,
      DashText
   );

   currentY += lineHeight;

   //===============================================================
   // EQUITY
   //===============================================================

   DrawDashboardLabel(
      "Equity",
      StringFormat(
         "Equity: $%.2f",
         equity
      ),
      startX,
      currentY,
      textsize,
      DashText
   );

   currentY += lineHeight;

   //===============================================================
   // FLOATING P/L
   //===============================================================

   DrawDashboardLabel(
      "FloatingPL",
      StringFormat(
         "Floating P/L: $%.2f",
         floatingPL
      ),
      startX,
      currentY,
      textsize,
      pnlColor
   );

   currentY += lineHeight + 5;

   //===============================================================
   // LIQUIDITY
   //===============================================================

   DrawDashboardLabel(
      "Liquidity",
      "Liquidity: " +
      GetLiquidityStatus(),
      startX,
      currentY,
      detailsSize,
      g_Liquidity.valid
         ? DashBuy
         : DashNeutral
   );

   currentY += lineHeight;

   //===============================================================
   // STRUCTURE
   //===============================================================

   DrawDashboardLabel(
      "Structure",
      "Structure: " +
      GetStructureStatus(),
      startX,
      currentY,
      detailsSize,
      g_Structure.valid
         ? DashBuy
         : DashNeutral
   );

   currentY += lineHeight;

   //===============================================================
   // ORDER BLOCK
   //===============================================================

   DrawDashboardLabel(
      "OrderBlock",
      "OrderBlock: " +
      GetOBStatus(),
      startX,
      currentY,
      detailsSize,
      g_OrderBlock.valid
         ? DashBuy
         : DashNeutral
   );

   currentY += lineHeight;

   //===============================================================
   // FVG
   //===============================================================

   DrawDashboardLabel(
      "FVG",
      "FVG: " +
      GetFVGStatus(),
      startX,
      currentY,
      detailsSize,
      g_OrderBlock.hasFVG
         ? DashBuy
         : DashNeutral
   );

   currentY += lineHeight;

   //===============================================================
   // ENTRY
   //===============================================================

   DrawDashboardLabel(
      "Entry",
      "Entry: " +
      GetEntryStatus(),
      startX,
      currentY,
      detailsSize,
      g_Entry.valid
         ? DashBuy
         : DashNeutral
   );

   currentY += lineHeight + 5;

   //===============================================================
   // POSITION
   //===============================================================

   DrawDashboardLabel(
      "Position",
      "Position: " + direction,
      startX,
      currentY,
      textsize,
      directionColor,
      true
   );

   currentY += lineHeight;

   //===============================================================
   // POSITION DETAILS
   //===============================================================

   if(hasPosition)
   {
      double volume =
         PositionGetDouble(
            POSITION_VOLUME
         );

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

      // LOT
   currentY += lineHeight+5;

      DrawDashboardLabel(
         "Lot",
         StringFormat(
            "Lot: %.2f",
            volume
         ),
         startX,
         currentY,
         detailsSize,
         DashText
      );

      currentY += lineHeight;

      // ENTRY PRICE

      DrawDashboardLabel(
         "EntryPrice",
         StringFormat(
            "Entry: %.*f",
            _Digits,
            entry
         ),
         startX,
         currentY,
         detailsSize,
         DashText
      );

      currentY += lineHeight;

      // SL

      DrawDashboardLabel(
         "SL",
         StringFormat(
            "SL: %.*f",
            _Digits,
            sl
         ),
         startX,
         currentY,
         detailsSize,
         DashText
      );

      currentY += lineHeight;

      // TP

      DrawDashboardLabel(
         "TP",
         StringFormat(
            "TP: %.*f",
            _Digits,
            tp
         ),
         startX,
         currentY,
         detailsSize,
         DashText
      );

      currentY += lineHeight;

      // CURRENT R

      double currentR =
         GetCurrentR();

      color rColor =
         DashText;

      if(currentR > 0.0)
         rColor = DashBuy;
      else
      if(currentR < 0.0)
         rColor = DashSell;

      DrawDashboardLabel(
         "CurrentR",
         StringFormat(
            "Current R: %.2f",
            currentR
         ),
         startX,
         currentY,
         detailsSize,
         rColor
      );

      currentY += lineHeight;

      // MANAGER

      DrawDashboardLabel(
         "Manager",
         "Manager: " +
         GetTradeManagementStage(),
         startX,
         currentY,
         detailsSize,
         DashOrange,
         true
      );

      currentY += lineHeight;
   }
   else
   {
      DrawDashboardLabel(
         "PositionInfo",
         "Position: NONE",
         startX,
         currentY,
         detailsSize,
         DashNeutral
      );

      currentY += lineHeight;
   }

   //===============================================================
   // IMPORTANT:
   // NO BACKGROUND IS CREATED HERE.
   //===============================================================

   ChartRedraw(0);
}


//+------------------------------------------------------------------+
//| INITIALIZE                                                       |
//+------------------------------------------------------------------+

void InitializeDashboard()
{
   // Remove ALL old dashboard objects first.
   DeleteDashboard();

   if(!InpShowDashboard)
      return;

   UpdateDashboard();
}


//+------------------------------------------------------------------+
//| SHUTDOWN                                                         |
//+------------------------------------------------------------------+

void ShutdownDashboard()
{
   DeleteDashboard();

   ChartRedraw(0);
}


//+------------------------------------------------------------------+

#endif
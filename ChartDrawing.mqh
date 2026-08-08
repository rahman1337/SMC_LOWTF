#ifndef SCALPINGEA_CHART_DRAWING_MQH
#define SCALPINGEA_CHART_DRAWING_MQH

#include "Constants.mqh"
#include "Structures.mqh"
#include "StructureEngine.mqh"
#include "OrderBlockEngine.mqh"

//+------------------------------------------------------------------+
//| CHART DRAWING SETTINGS                                           |
//+------------------------------------------------------------------+

input group "=== CHART DRAWING ==="

input bool InpDrawLiquidity        = true;
input bool InpDrawStructure        = true;
input bool InpDrawOrderBlock       = true;
input bool InpDrawFVG              = true;
input bool InpDrawEntry            = true;
input bool InpDrawDashboard        = true;

input bool InpDrawOnlyCurrentSetup = true;

input int  InpDrawingLineWidth     = 1;

input int  InpOBRectangleBars      = 30;
input int  InpFVGRectangleBars     = 20;

input bool InpDrawPriceLabels      = true;

//+------------------------------------------------------------------+
//| Object Prefix                                                     |
//+------------------------------------------------------------------+

#define DRAW_PREFIX "SCALPINGEA_"

//+------------------------------------------------------------------+
//| Object Names                                                      |
//+------------------------------------------------------------------+

#define OBJ_LIQUIDITY_LINE       DRAW_PREFIX "LIQUIDITY_LINE"
#define OBJ_LIQUIDITY_LABEL      DRAW_PREFIX "LIQUIDITY_LABEL"
#define OBJ_SWEEP_ARROW          DRAW_PREFIX "SWEEP_ARROW"

#define OBJ_STRUCTURE_LINE       DRAW_PREFIX "STRUCTURE_LINE"
#define OBJ_STRUCTURE_LABEL      DRAW_PREFIX "STRUCTURE_LABEL"

#define OBJ_OB_RECTANGLE         DRAW_PREFIX "OB_RECTANGLE"
#define OBJ_OB_LABEL             DRAW_PREFIX "OB_LABEL"

#define OBJ_FVG_RECTANGLE        DRAW_PREFIX "FVG_RECTANGLE"
#define OBJ_FVG_LABEL            DRAW_PREFIX "FVG_LABEL"

#define OBJ_ENTRY_LINE           DRAW_PREFIX "ENTRY_LINE"
#define OBJ_SL_LINE              DRAW_PREFIX "SL_LINE"
#define OBJ_TP_LINE              DRAW_PREFIX "TP_LINE"

#define OBJ_ENTRY_LABEL          DRAW_PREFIX "ENTRY_LABEL"
#define OBJ_SL_LABEL             DRAW_PREFIX "SL_LABEL"
#define OBJ_TP_LABEL             DRAW_PREFIX "TP_LABEL"

#define OBJ_DASHBOARD_BG         DRAW_PREFIX "DASH_BG"
#define OBJ_DASHBOARD_TITLE      DRAW_PREFIX "DASH_TITLE"
#define OBJ_DASHBOARD_LIQ        DRAW_PREFIX "DASH_LIQ"
#define OBJ_DASHBOARD_STRUCTURE  DRAW_PREFIX "DASH_STRUCTURE"
#define OBJ_DASHBOARD_OB         DRAW_PREFIX "DASH_OB"
#define OBJ_DASHBOARD_ENTRY      DRAW_PREFIX "DASH_ENTRY"
#define OBJ_DASHBOARD_STATUS     DRAW_PREFIX "DASH_STATUS"

//+------------------------------------------------------------------+
//| Delete Object                                                    |
//+------------------------------------------------------------------+

void DeleteDrawingObject(string name)
{
   if(ObjectFind(0,name) >= 0)
      ObjectDelete(0,name);
}

//+------------------------------------------------------------------+
//| Delete All EA Drawing Objects                                    |
//+------------------------------------------------------------------+

void DeleteAllDrawingObjects()
{
   int total = ObjectsTotal(0,-1,-1);

   for(int i=total-1; i>=0; i--)
   {
      string name = ObjectName(0,i,-1,-1);

      if(StringFind(name,DRAW_PREFIX) == 0)
         ObjectDelete(0,name);
   }
}

//+------------------------------------------------------------------+
//| Create Horizontal Line                                          |
//+------------------------------------------------------------------+

bool DrawHorizontalLine(
   string name,
   double price,
   color lineColor,
   ENUM_LINE_STYLE style=STYLE_SOLID,
   int width=1
)
{
   if(price <= 0.0)
      return false;

   if(ObjectFind(0,name) < 0)
   {
      if(!ObjectCreate(
            0,
            name,
            OBJ_HLINE,
            0,
            0,
            price
         ))
      {
         return false;
      }
   }

   ObjectSetDouble(
      0,
      name,
      OBJPROP_PRICE,
      price
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      lineColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_STYLE,
      style
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      width
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   return true;
}

//+------------------------------------------------------------------+
//| Create Text Label                                                 |
//+------------------------------------------------------------------+

bool DrawTextLabel(
   string name,
   datetime time,
   double price,
   string text,
   color textColor,
   int fontSize=9
)
{
   if(price <= 0.0)
      return false;

   if(ObjectFind(0,name) < 0)
   {
      if(!ObjectCreate(
            0,
            name,
            OBJ_TEXT,
            0,
            time,
            price
         ))
      {
         return false;
      }
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_TIME,
      time
   );

   ObjectSetDouble(
      0,
      name,
      OBJPROP_PRICE,
      price
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      fontSize
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      textColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ANCHOR,
      ANCHOR_LEFT
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      false
   );

   return true;
}

//+------------------------------------------------------------------+
//| Create Rectangle                                                 |
//+------------------------------------------------------------------+

bool DrawRectangle(
   string name,
   datetime time1,
   double price1,
   datetime time2,
   double price2,
   color rectangleColor
)
{
   if(price1 <= 0.0 ||
      price2 <= 0.0 ||
      time1 <= 0 ||
      time2 <= 0)
   {
      return false;
   }

   if(ObjectFind(0,name) < 0)
   {
      if(!ObjectCreate(
            0,
            name,
            OBJ_RECTANGLE,
            0,
            time1,
            price1,
            time2,
            price2
         ))
      {
         return false;
      }
   }
   else
   {
      ObjectMove(
         0,
         name,
         0,
         time1,
         price1
      );

      ObjectMove(
         0,
         name,
         1,
         time2,
         price2
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      rectangleColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_STYLE,
      STYLE_SOLID
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      1
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FILL,
      true
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      true
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   return true;
}

//+------------------------------------------------------------------+
//| Draw Liquidity Sweep                                             |
//+------------------------------------------------------------------+

void DrawLiquiditySweep()
{
   if(!InpDrawLiquidity)
      return;

   if(!g_Liquidity.valid)
   {
      DeleteDrawingObject(OBJ_LIQUIDITY_LINE);
      DeleteDrawingObject(OBJ_LIQUIDITY_LABEL);
      DeleteDrawingObject(OBJ_SWEEP_ARROW);

      return;
   }

   double price =
      g_Liquidity.liquidityPrice;

   if(price <= 0.0)
      return;

   color lineColor;

   if(g_Liquidity.direction == BIAS_BULLISH)
      lineColor = clrLimeGreen;
   else
      lineColor = clrTomato;

   DrawHorizontalLine(
      OBJ_LIQUIDITY_LINE,
      price,
      lineColor,
      STYLE_DASH,
      InpDrawingLineWidth
   );

   if(InpDrawPriceLabels)
   {
      string text;

      if(g_Liquidity.direction == BIAS_BULLISH)
         text = "BULLISH LIQUIDITY SWEEP";
      else
         text = "BEARISH LIQUIDITY SWEEP";

      DrawTextLabel(
         OBJ_LIQUIDITY_LABEL,
         g_Liquidity.sweepTime,
         price,
         text,
         lineColor,
         9
      );
   }

   //===============================================================
   // Sweep marker
   //===============================================================

   if(g_Liquidity.sweepTime > 0)
   {
      datetime markerTime =
         g_Liquidity.sweepTime;

      double markerPrice;

      if(g_Liquidity.direction == BIAS_BULLISH)
         markerPrice = g_Liquidity.sweepLow;
      else
         markerPrice = g_Liquidity.sweepHigh;

      if(markerPrice > 0.0)
      {
         if(ObjectFind(0,OBJ_SWEEP_ARROW) < 0)
         {
            ObjectCreate(
               0,
               OBJ_SWEEP_ARROW,
               OBJ_ARROW,
               0,
               markerTime,
               markerPrice
            );
         }

         ObjectMove(
            0,
            OBJ_SWEEP_ARROW,
            0,
            markerTime,
            markerPrice
         );

         if(g_Liquidity.direction == BIAS_BULLISH)
         {
            ObjectSetInteger(
               0,
               OBJ_SWEEP_ARROW,
               OBJPROP_ARROWCODE,
               233
            );

            ObjectSetInteger(
               0,
               OBJ_SWEEP_ARROW,
               OBJPROP_COLOR,
               clrLimeGreen
            );
         }
         else
         {
            ObjectSetInteger(
               0,
               OBJ_SWEEP_ARROW,
               OBJPROP_ARROWCODE,
               234
            );

            ObjectSetInteger(
               0,
               OBJ_SWEEP_ARROW,
               OBJPROP_COLOR,
               clrTomato
            );
         }

         ObjectSetInteger(
            0,
            OBJ_SWEEP_ARROW,
            OBJPROP_WIDTH,
            2
         );

         ObjectSetInteger(
            0,
            OBJ_SWEEP_ARROW,
            OBJPROP_SELECTABLE,
            false
         );
      }
   }
}

//+------------------------------------------------------------------+
//| Draw M5 Structure                                                |
//+------------------------------------------------------------------+

void DrawM5Structure()
{
   if(!InpDrawStructure)
      return;

   if(!g_Structure.valid)
   {
      DeleteDrawingObject(OBJ_STRUCTURE_LINE);
      DeleteDrawingObject(OBJ_STRUCTURE_LABEL);

      return;
   }

   if(g_Structure.brokenSwing <= 0.0)
      return;

   color structureColor;

   if(g_Structure.direction == BIAS_BULLISH)
      structureColor = clrDeepSkyBlue;
   else
      structureColor = clrOrangeRed;

   DrawHorizontalLine(
      OBJ_STRUCTURE_LINE,
      g_Structure.brokenSwing,
      structureColor,
      STYLE_DOT,
      2
   );

   if(InpDrawPriceLabels)
   {
      string text;

      if(g_Structure.direction == BIAS_BULLISH)
      {
         if(g_Structure.mss)
            text = "M5 BULLISH MSS / BOS";
         else
            text = "M5 BULLISH BOS";
      }
      else
      {
         if(g_Structure.mss)
            text = "M5 BEARISH MSS / BOS";
         else
            text = "M5 BEARISH BOS";
      }

      DrawTextLabel(
         OBJ_STRUCTURE_LABEL,
         g_Structure.confirmationTime,
         g_Structure.brokenSwing,
         text,
         structureColor,
         9
      );
   }
}

//+------------------------------------------------------------------+
//| Get Future Drawing Time                                          |
//+------------------------------------------------------------------+

datetime GetFutureDrawingTime(
   ENUM_TIMEFRAMES timeframe,
   int barsForward
)
{
   datetime currentTime =
      iTime(
         _Symbol,
         timeframe,
         0
      );

   if(currentTime <= 0)
      return 0;

   int seconds =
      PeriodSeconds(timeframe);

   if(seconds <= 0)
      seconds = 60;

   return currentTime +
          seconds * barsForward;
}

//+------------------------------------------------------------------+
//| Draw Order Block                                                 |
//+------------------------------------------------------------------+

void DrawOrderBlock()
{
   if(!InpDrawOrderBlock)
      return;

   if(!g_OrderBlock.valid)
   {
      DeleteDrawingObject(OBJ_OB_RECTANGLE);
      DeleteDrawingObject(OBJ_OB_LABEL);

      return;
   }

   if(g_OrderBlock.high <= 0.0 ||
      g_OrderBlock.low <= 0.0)
   {
      return;
   }

   ENUM_TIMEFRAMES timeframe =
      PERIOD_M5;

   // M1 OB is identified by its shift/time,
   // but the state does not explicitly store TF.
   // Therefore use M5 for visual extension.

   datetime startTime =
      g_OrderBlock.createdTime;

   datetime endTime =
      GetFutureDrawingTime(
         timeframe,
         InpOBRectangleBars
      );

   if(startTime <= 0 ||
      endTime <= 0)
   {
      return;
   }

   color obColor;

   if(g_OrderBlock.direction == BIAS_BULLISH)
      obColor = clrDarkSeaGreen;
   else
      obColor = clrIndianRed;

   DrawRectangle(
      OBJ_OB_RECTANGLE,
      startTime,
      g_OrderBlock.high,
      endTime,
      g_OrderBlock.low,
      obColor
   );

   if(InpDrawPriceLabels)
   {
      string text;

      if(g_OrderBlock.direction == BIAS_BULLISH)
         text = "BULLISH OB";
      else
         text = "BEARISH OB";

      if(g_OrderBlock.hasFVG)
         text += " + FVG";

      DrawTextLabel(
         OBJ_OB_LABEL,
         startTime,
         g_OrderBlock.high,
         text,
         obColor,
         9
      );
   }
}

//+------------------------------------------------------------------+
//| Draw FVG                                                         |
//+------------------------------------------------------------------+

void DrawOrderBlockFVG()
{
   if(!InpDrawFVG)
      return;

   if(!g_OrderBlock.valid ||
      !g_OrderBlock.hasFVG)
   {
      DeleteDrawingObject(OBJ_FVG_RECTANGLE);
      DeleteDrawingObject(OBJ_FVG_LABEL);

      return;
   }

   if(g_OrderBlock.fvgHigh <= 0.0 ||
      g_OrderBlock.fvgLow <= 0.0)
   {
      return;
   }

   datetime startTime =
      g_OrderBlock.createdTime;

   datetime endTime =
      GetFutureDrawingTime(
         PERIOD_M5,
         InpFVGRectangleBars
      );

   if(startTime <= 0 ||
      endTime <= 0)
   {
      return;
   }

   color fvgColor;

   if(g_OrderBlock.direction == BIAS_BULLISH)
      fvgColor = clrDodgerBlue;
   else
      fvgColor = clrViolet;

   DrawRectangle(
      OBJ_FVG_RECTANGLE,
      startTime,
      g_OrderBlock.fvgHigh,
      endTime,
      g_OrderBlock.fvgLow,
      fvgColor
   );

   if(InpDrawPriceLabels)
   {
      string text = "FVG";

      if(g_OrderBlock.fvgInsideOB)
         text = "FVG INSIDE OB";

      DrawTextLabel(
         OBJ_FVG_LABEL,
         startTime,
         g_OrderBlock.fvgHigh,
         text,
         fvgColor,
         8
      );
   }
}

//+------------------------------------------------------------------+
//| Draw Entry Levels                                                |
//+------------------------------------------------------------------+

void DrawEntryConfirmation(
EntryConfirmationState &entry
)
{
   if(!InpDrawEntry)
      return;

   if(!entry.valid)
   {
      DeleteDrawingObject(OBJ_ENTRY_LINE);
      DeleteDrawingObject(OBJ_SL_LINE);
      DeleteDrawingObject(OBJ_TP_LINE);

      DeleteDrawingObject(OBJ_ENTRY_LABEL);
      DeleteDrawingObject(OBJ_SL_LABEL);
      DeleteDrawingObject(OBJ_TP_LABEL);

      return;
   }

   if(entry.entryPrice <= 0.0)
      return;

   DrawHorizontalLine(
      OBJ_ENTRY_LINE,
      entry.entryPrice,
      clrWhite,
      STYLE_SOLID,
      2
   );

   if(entry.stopLoss > 0.0)
   {
      DrawHorizontalLine(
         OBJ_SL_LINE,
         entry.stopLoss,
         clrRed,
         STYLE_DASH,
         1
      );
   }

   if(entry.takeProfit > 0.0)
   {
      DrawHorizontalLine(
         OBJ_TP_LINE,
         entry.takeProfit,
         clrLime,
         STYLE_DASH,
         1
      );
   }

   if(InpDrawPriceLabels)
   {
      datetime labelTime =
         entry.confirmationTime;

      if(labelTime <= 0)
         labelTime = iTime(
            _Symbol,
            PERIOD_M5,
            0
         );

      DrawTextLabel(
         OBJ_ENTRY_LABEL,
         labelTime,
         entry.entryPrice,
         "ENTRY",
         clrWhite,
         9
      );

      if(entry.stopLoss > 0.0)
      {
         DrawTextLabel(
            OBJ_SL_LABEL,
            labelTime,
            entry.stopLoss,
            "SL",
            clrRed,
            9
         );
      }

      if(entry.takeProfit > 0.0)
      {
         DrawTextLabel(
            OBJ_TP_LABEL,
            labelTime,
            entry.takeProfit,
            "TP",
            clrLime,
            9
         );
      }
   }
}

//+------------------------------------------------------------------+
//| Dashboard Object                                                 |
//+------------------------------------------------------------------+

void CreateDashboardLabel(
   string name,
   int x,
   int y,
   string text,
   color textColor,
   int fontSize=9
)
{
   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      fontSize
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      textColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );
}

//+------------------------------------------------------------------+
//| Draw Dashboard                                                   |
//+------------------------------------------------------------------+

void DrawChartDashboard()
{
   if(!InpDrawDashboard)
      return;

   //===============================================================
   // TITLE
   //===============================================================

   CreateDashboardLabel(
      OBJ_DASHBOARD_TITLE,
      15,
      20,
      "SCALPING EA",
      clrWhite,
      11
   );

   //===============================================================
   // LIQUIDITY
   //===============================================================

   string liquidityText;

   color liquidityColor;

   if(g_Liquidity.valid)
   {
      if(g_Liquidity.direction == BIAS_BULLISH)
      {
         liquidityText =
            "Liquidity : BULLISH SWEEP";

         liquidityColor =
            clrLimeGreen;
      }
      else
      {
         liquidityText =
            "Liquidity : BEARISH SWEEP";

         liquidityColor =
            clrTomato;
      }
   }
   else
   {
      liquidityText =
         "Liquidity : WAITING";

      liquidityColor =
         clrSilver;
   }

   CreateDashboardLabel(
      OBJ_DASHBOARD_LIQ,
      15,
      42,
      liquidityText,
      liquidityColor,
      9
   );

   //===============================================================
   // STRUCTURE
   //===============================================================

   string structureText;

   color structureColor;

   if(g_Structure.valid)
   {
      if(g_Structure.direction == BIAS_BULLISH)
      {
         structureText =
            "Structure : BULLISH MSS/BOS";

         structureColor =
            clrDeepSkyBlue;
      }
      else
      {
         structureText =
            "Structure : BEARISH MSS/BOS";

         structureColor =
            clrOrange;
      }
   }
   else
   {
      structureText =
         "Structure : WAITING";

      structureColor =
         clrSilver;
   }

   CreateDashboardLabel(
      OBJ_DASHBOARD_STRUCTURE,
      15,
      62,
      structureText,
      structureColor,
      9
   );

   //===============================================================
   // ORDER BLOCK
   //===============================================================

   string obText;

   color obColor;

   if(g_OrderBlock.valid)
   {
      if(g_OrderBlock.direction == BIAS_BULLISH)
      {
         obText =
            "Order Block : BULLISH";

         obColor =
            clrDarkSeaGreen;
      }
      else
      {
         obText =
            "Order Block : BEARISH";

         obColor =
            clrIndianRed;
      }

      if(g_OrderBlock.hasFVG)
         obText += " + FVG";
   }
   else
   {
      obText =
         "Order Block : WAITING";

      obColor =
         clrSilver;
   }

   CreateDashboardLabel(
      OBJ_DASHBOARD_OB,
      15,
      82,
      obText,
      obColor,
      9
   );

   //===============================================================
   // ENTRY
   //===============================================================

   string entryText;

   color entryColor;

   entryText =
      "Entry : WAITING";

   entryColor =
      clrSilver;

   CreateDashboardLabel(
      OBJ_DASHBOARD_ENTRY,
      15,
      102,
      entryText,
      entryColor,
      9
   );

   //===============================================================
   // OVERALL STATUS
   //===============================================================

   string statusText;

   color statusColor;

   if(g_Liquidity.valid &&
      g_Structure.valid &&
      g_OrderBlock.valid)
   {
      statusText =
         "STATUS : SETUP READY";

      statusColor =
         clrLimeGreen;
   }
   else
   {
      statusText =
         "STATUS : ANALYZING";

      statusColor =
         clrSilver;
   }

   CreateDashboardLabel(
      OBJ_DASHBOARD_STATUS,
      15,
      124,
      statusText,
      statusColor,
      10
   );
}

//+------------------------------------------------------------------+
//| Update All Chart Drawings                                        |
//+------------------------------------------------------------------+

void UpdateChartDrawings()
{
   DrawLiquiditySweep();

   DrawM5Structure();

   DrawOrderBlock();

   DrawOrderBlockFVG();

   DrawChartDashboard();

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+

void InitializeChartDrawing()
{
   DeleteAllDrawingObjects();

   UpdateChartDrawings();
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+

void ReleaseChartDrawing()
{
   DeleteAllDrawingObjects();

   ChartRedraw();
}

//+------------------------------------------------------------------+

#endif
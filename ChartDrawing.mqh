#ifndef SCALPINGEA_CHART_DRAWING_MQH
#define SCALPINGEA_CHART_DRAWING_MQH

#include "Constants.mqh"
#include "Structures.mqh"
#include "StructureEngine.mqh"
#include "OrderBlockEngine.mqh"
#include "EntryEngine.mqh"

//+------------------------------------------------------------------+
//| CHART DRAWING SETTINGS                                           |
//+------------------------------------------------------------------+

input group "=== CHART DRAWING ==="

input bool InpDrawLiquidity        = true;
input bool InpDrawStructure        = true;
input bool InpDrawOrderBlock       = true;
input bool InpDrawFVG              = true;
input bool InpDrawEntry            = true;

input bool InpDrawOnlyCurrentSetup = true;

input int  InpDrawingLineWidth     = 1;

input int  InpOBRectangleBars      = 30;
input int  InpFVGRectangleBars     = 20;

input bool InpDrawPriceLabels      = true;

//+------------------------------------------------------------------+
//| PREFIX                                                           |
//+------------------------------------------------------------------+

#define DRAW_PREFIX "SCALPINGEA_"

//+------------------------------------------------------------------+
//| OBJECT NAMES                                                      |
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

//+------------------------------------------------------------------+
//| DELETE OBJECT                                                    |
//+------------------------------------------------------------------+

void DeleteDrawingObject(string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

//+------------------------------------------------------------------+
//| DELETE ALL DRAWING OBJECTS                                       |
//+------------------------------------------------------------------+

void DeleteAllDrawingObjects()
{
   int total =
      ObjectsTotal(
         0,
         -1,
         -1
      );

   for(int i = total - 1; i >= 0; i--)
   {
      string name =
         ObjectName(
            0,
            i,
            -1,
            -1
         );

      if(StringFind(
            name,
            DRAW_PREFIX
         ) == 0)
      {
         ObjectDelete(
            0,
            name
         );
      }
   }
}

//+------------------------------------------------------------------+
//| HORIZONTAL LINE                                                  |
//+------------------------------------------------------------------+

bool DrawHorizontalLine(
   string name,
   double price,
   color lineColor,
   ENUM_LINE_STYLE style = STYLE_SOLID,
   int width = 1
)
{
   if(price <= 0.0)
      return false;

   if(ObjectFind(0, name) < 0)
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

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );

   return true;
}

//+------------------------------------------------------------------+
//| TEXT LABEL                                                       |
//+------------------------------------------------------------------+

bool DrawTextLabel(
   string name,
   datetime time,
   double price,
   string text,
   color textColor,
   int fontSize = 9
)
{
   if(
      price <= 0.0 ||
      time <= 0
   )
   {
      return false;
   }

   if(ObjectFind(0, name) < 0)
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
   else
   {
      ObjectMove(
         0,
         name,
         0,
         time,
         price
      );
   }

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
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
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
//| RECTANGLE                                                        |
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
   if(
      price1 <= 0.0 ||
      price2 <= 0.0 ||
      time1 <= 0 ||
      time2 <= 0
   )
   {
      return false;
   }

   if(ObjectFind(0, name) < 0)
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

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );

   return true;
}

//+------------------------------------------------------------------+
//| FUTURE DRAWING TIME                                              |
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

   return
      currentTime +
      seconds * barsForward;
}

//+------------------------------------------------------------------+
//| LIQUIDITY SWEEP                                                  |
//+------------------------------------------------------------------+

void DrawLiquiditySweep()
{
   if(!InpDrawLiquidity)
   {
      DeleteDrawingObject(
         OBJ_LIQUIDITY_LINE
      );

      DeleteDrawingObject(
         OBJ_LIQUIDITY_LABEL
      );

      DeleteDrawingObject(
         OBJ_SWEEP_ARROW
      );

      return;
   }

   if(!g_Liquidity.valid)
   {
      DeleteDrawingObject(
         OBJ_LIQUIDITY_LINE
      );

      DeleteDrawingObject(
         OBJ_LIQUIDITY_LABEL
      );

      DeleteDrawingObject(
         OBJ_SWEEP_ARROW
      );

      return;
   }

   double price =
      g_Liquidity.liquidityPrice;

   if(price <= 0.0)
      return;

   color lineColor =
      clrSilver;

   if(g_Liquidity.direction == BIAS_BULLISH)
      lineColor = clrLimeGreen;
   else
   if(g_Liquidity.direction == BIAS_BEARISH)
      lineColor = clrTomato;

   DrawHorizontalLine(
      OBJ_LIQUIDITY_LINE,
      price,
      lineColor,
      STYLE_DASH,
      InpDrawingLineWidth
   );

   //===============================================================
   // LABEL
   //===============================================================

   if(InpDrawPriceLabels)
   {
      string text =
         "LIQUIDITY SWEEP";

      if(g_Liquidity.direction == BIAS_BULLISH)
         text = "BULLISH LIQUIDITY SWEEP";
      else
      if(g_Liquidity.direction == BIAS_BEARISH)
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
   else
   {
      DeleteDrawingObject(
         OBJ_LIQUIDITY_LABEL
      );
   }

   //===============================================================
   // SWEEP ARROW
   //===============================================================

   if(g_Liquidity.sweepTime <= 0)
   {
      DeleteDrawingObject(
         OBJ_SWEEP_ARROW
      );

      return;
   }

   double markerPrice = 0.0;

   if(g_Liquidity.direction == BIAS_BULLISH)
      markerPrice = g_Liquidity.sweepLow;
   else
   if(g_Liquidity.direction == BIAS_BEARISH)
      markerPrice = g_Liquidity.sweepHigh;

   if(markerPrice <= 0.0)
   {
      DeleteDrawingObject(
         OBJ_SWEEP_ARROW
      );

      return;
   }

   if(ObjectFind(
         0,
         OBJ_SWEEP_ARROW
      ) < 0)
   {
      ObjectCreate(
         0,
         OBJ_SWEEP_ARROW,
         OBJ_ARROW,
         0,
         g_Liquidity.sweepTime,
         markerPrice
      );
   }
   else
   {
      ObjectMove(
         0,
         OBJ_SWEEP_ARROW,
         0,
         g_Liquidity.sweepTime,
         markerPrice
      );
   }

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

   ObjectSetInteger(
      0,
      OBJ_SWEEP_ARROW,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      OBJ_SWEEP_ARROW,
      OBJPROP_HIDDEN,
      true
   );
}

//+------------------------------------------------------------------+
//| M5 STRUCTURE                                                     |
//+------------------------------------------------------------------+

void DrawM5Structure()
{
   if(!InpDrawStructure)
   {
      DeleteDrawingObject(
         OBJ_STRUCTURE_LINE
      );

      DeleteDrawingObject(
         OBJ_STRUCTURE_LABEL
      );

      return;
   }

   if(!g_Structure.valid)
   {
      DeleteDrawingObject(
         OBJ_STRUCTURE_LINE
      );

      DeleteDrawingObject(
         OBJ_STRUCTURE_LABEL
      );

      return;
   }

   if(g_Structure.brokenSwing <= 0.0)
      return;

   color structureColor =
      clrSilver;

   if(g_Structure.direction == BIAS_BULLISH)
      structureColor = clrDeepSkyBlue;
   else
   if(g_Structure.direction == BIAS_BEARISH)
      structureColor = clrOrangeRed;

   DrawHorizontalLine(
      OBJ_STRUCTURE_LINE,
      g_Structure.brokenSwing,
      structureColor,
      STYLE_DOT,
      2
   );

   if(!InpDrawPriceLabels)
   {
      DeleteDrawingObject(
         OBJ_STRUCTURE_LABEL
      );

      return;
   }

   string text = "";

   if(g_Structure.direction == BIAS_BULLISH)
   {
      if(g_Structure.mss)
         text = "M5 BULLISH MSS / BOS";
      else
      if(g_Structure.bos)
         text = "M5 BULLISH BOS";
      else
         text = "M5 BULLISH STRUCTURE";
   }
   else
   if(g_Structure.direction == BIAS_BEARISH)
   {
      if(g_Structure.mss)
         text = "M5 BEARISH MSS / BOS";
      else
      if(g_Structure.bos)
         text = "M5 BEARISH BOS";
      else
         text = "M5 BEARISH STRUCTURE";
   }
   else
   {
      text = "M5 STRUCTURE";
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

//+------------------------------------------------------------------+
//| ORDER BLOCK                                                      |
//+------------------------------------------------------------------+

void DrawOrderBlock()
{
   if(!InpDrawOrderBlock)
   {
      DeleteDrawingObject(
         OBJ_OB_RECTANGLE
      );

      DeleteDrawingObject(
         OBJ_OB_LABEL
      );

      return;
   }

   if(!g_OrderBlock.valid)
   {
      DeleteDrawingObject(
         OBJ_OB_RECTANGLE
      );

      DeleteDrawingObject(
         OBJ_OB_LABEL
      );

      return;
   }

   if(
      g_OrderBlock.high <= 0.0 ||
      g_OrderBlock.low <= 0.0
   )
   {
      DeleteDrawingObject(
         OBJ_OB_RECTANGLE
      );

      DeleteDrawingObject(
         OBJ_OB_LABEL
      );

      return;
   }

   datetime startTime =
      g_OrderBlock.createdTime;

   datetime endTime =
      GetFutureDrawingTime(
         PERIOD_M5,
         InpOBRectangleBars
      );

   if(
      startTime <= 0 ||
      endTime <= 0
   )
   {
      return;
   }

   color obColor =
      clrSilver;

   if(g_OrderBlock.direction == BIAS_BULLISH)
      obColor = clrDarkSeaGreen;
   else
   if(g_OrderBlock.direction == BIAS_BEARISH)
      obColor = clrIndianRed;

   DrawRectangle(
      OBJ_OB_RECTANGLE,
      startTime,
      g_OrderBlock.high,
      endTime,
      g_OrderBlock.low,
      obColor
   );

   if(!InpDrawPriceLabels)
   {
      DeleteDrawingObject(
         OBJ_OB_LABEL
      );

      return;
   }

   string text =
      "ORDER BLOCK";

   if(g_OrderBlock.direction == BIAS_BULLISH)
      text = "BULLISH OB";
   else
   if(g_OrderBlock.direction == BIAS_BEARISH)
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

//+------------------------------------------------------------------+
//| ORDER BLOCK FVG                                                  |
//+------------------------------------------------------------------+

void DrawOrderBlockFVG()
{
   if(!InpDrawFVG)
   {
      DeleteDrawingObject(
         OBJ_FVG_RECTANGLE
      );

      DeleteDrawingObject(
         OBJ_FVG_LABEL
      );

      return;
   }

   if(
      !g_OrderBlock.valid ||
      !g_OrderBlock.hasFVG
   )
   {
      DeleteDrawingObject(
         OBJ_FVG_RECTANGLE
      );

      DeleteDrawingObject(
         OBJ_FVG_LABEL
      );

      return;
   }

   if(
      g_OrderBlock.fvgHigh <= 0.0 ||
      g_OrderBlock.fvgLow <= 0.0
   )
   {
      DeleteDrawingObject(
         OBJ_FVG_RECTANGLE
      );

      DeleteDrawingObject(
         OBJ_FVG_LABEL
      );

      return;
   }

   datetime startTime =
      g_OrderBlock.createdTime;

   datetime endTime =
      GetFutureDrawingTime(
         PERIOD_M5,
         InpFVGRectangleBars
      );

   if(
      startTime <= 0 ||
      endTime <= 0
   )
   {
      return;
   }

   color fvgColor =
      clrDodgerBlue;

   if(g_OrderBlock.direction == BIAS_BEARISH)
      fvgColor = clrViolet;

   DrawRectangle(
      OBJ_FVG_RECTANGLE,
      startTime,
      g_OrderBlock.fvgHigh,
      endTime,
      g_OrderBlock.fvgLow,
      fvgColor
   );

   if(!InpDrawPriceLabels)
   {
      DeleteDrawingObject(
         OBJ_FVG_LABEL
      );

      return;
   }

   string text =
      "FVG";

   if(g_OrderBlock.fvgInsideOB)
      text = "FVG INSIDE OB";
   else
   if(g_OrderBlock.fvgBesideOB)
      text = "FVG BESIDE OB";
   else
   if(g_OrderBlock.fvgNearOB)
      text = "FVG NEAR OB";

   DrawTextLabel(
      OBJ_FVG_LABEL,
      startTime,
      g_OrderBlock.fvgHigh,
      text,
      fvgColor,
      8
   );
}

//+------------------------------------------------------------------+
//| ENTRY CONFIRMATION                                               |
//+------------------------------------------------------------------+

void DrawEntryConfirmation(
   EntryConfirmationState &entry
)
{
   if(!InpDrawEntry)
   {
      DeleteDrawingObject(
         OBJ_ENTRY_LINE
      );

      DeleteDrawingObject(
         OBJ_SL_LINE
      );

      DeleteDrawingObject(
         OBJ_TP_LINE
      );

      DeleteDrawingObject(
         OBJ_ENTRY_LABEL
      );

      DeleteDrawingObject(
         OBJ_SL_LABEL
      );

      DeleteDrawingObject(
         OBJ_TP_LABEL
      );

      return;
   }

   if(!entry.valid)
   {
      DeleteDrawingObject(
         OBJ_ENTRY_LINE
      );

      DeleteDrawingObject(
         OBJ_SL_LINE
      );

      DeleteDrawingObject(
         OBJ_TP_LINE
      );

      DeleteDrawingObject(
         OBJ_ENTRY_LABEL
      );

      DeleteDrawingObject(
         OBJ_SL_LABEL
      );

      DeleteDrawingObject(
         OBJ_TP_LABEL
      );

      return;
   }

   //===============================================================
   // ENTRY
   //===============================================================

   if(entry.entryPrice > 0.0)
   {
      DrawHorizontalLine(
         OBJ_ENTRY_LINE,
         entry.entryPrice,
         clrWhite,
         STYLE_SOLID,
         2
      );
   }
   else
   {
      DeleteDrawingObject(
         OBJ_ENTRY_LINE
      );
   }

   //===============================================================
   // SL
   //===============================================================

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
   else
   {
      DeleteDrawingObject(
         OBJ_SL_LINE
      );
   }

   //===============================================================
   // TP
   //===============================================================

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
   else
   {
      DeleteDrawingObject(
         OBJ_TP_LINE
      );
   }

   //===============================================================
   // LABEL TIME
   //===============================================================

   datetime labelTime =
      entry.confirmationTime;

   if(labelTime <= 0)
   {
      labelTime =
         iTime(
            _Symbol,
            PERIOD_M5,
            0
         );
   }

   if(!InpDrawPriceLabels)
   {
      DeleteDrawingObject(
         OBJ_ENTRY_LABEL
      );

      DeleteDrawingObject(
         OBJ_SL_LABEL
      );

      DeleteDrawingObject(
         OBJ_TP_LABEL
      );

      return;
   }

   //===============================================================
   // ENTRY LABEL
   //===============================================================

   if(entry.entryPrice > 0.0)
   {
      DrawTextLabel(
         OBJ_ENTRY_LABEL,
         labelTime,
         entry.entryPrice,
         "ENTRY",
         clrWhite,
         9
      );
   }

   //===============================================================
   // SL LABEL
   //===============================================================

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

   //===============================================================
   // TP LABEL
   //===============================================================

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

//+------------------------------------------------------------------+
//| UPDATE ALL CHART DRAWINGS                                       |
//+------------------------------------------------------------------+

void UpdateChartDrawings()
{
   DrawLiquiditySweep();

   DrawM5Structure();

   DrawOrderBlock();

   DrawOrderBlockFVG();

   DrawEntryConfirmation(
      g_Entry
   );

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| INITIALIZE                                                       |
//+------------------------------------------------------------------+

void InitializeChartDrawing()
{
   DeleteAllDrawingObjects();

   UpdateChartDrawings();
}

//+------------------------------------------------------------------+
//| RELEASE                                                          |
//+------------------------------------------------------------------+

void ReleaseChartDrawing()
{
   DeleteAllDrawingObjects();

   ChartRedraw(0);
}

//+------------------------------------------------------------------+

#endif

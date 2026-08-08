#ifndef __SCALPINGEA_CONSTANTS_MQH__
#define __SCALPINGEA_CONSTANTS_MQH__

//+------------------------------------------------------------------+
//| Direction                                                        |
//+------------------------------------------------------------------+
enum ENUM_BIAS
{
   BIAS_NONE = 0,
   BIAS_BULLISH = 1,
   BIAS_BEARISH = -1
};

//+------------------------------------------------------------------+
//| Structure                                                        |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE
{
   STRUCTURE_NONE = 0,
   STRUCTURE_BULLISH,
   STRUCTURE_BEARISH
};

//+------------------------------------------------------------------+
//| Liquidity                                                        |
//+------------------------------------------------------------------+
enum ENUM_LIQUIDITY_TYPE
{
   LIQUIDITY_NONE = 0,
   LIQUIDITY_BUY_SIDE,
   LIQUIDITY_SELL_SIDE,
   LIQUIDITY_EQUAL_HIGH,
   LIQUIDITY_EQUAL_LOW
};

//+------------------------------------------------------------------+
//| Confirmation                                                     |
//+------------------------------------------------------------------+
enum ENUM_CONFIRMATION
{
   CONFIRM_NONE = 0,
   CONFIRM_BOS,
   CONFIRM_MSS,
   CONFIRM_CHOCH,
   CONFIRM_IFVG
};

//+------------------------------------------------------------------+
//| Order Block                                                      |
//+------------------------------------------------------------------+
enum ENUM_OB_TYPE
{
   OB_NONE = 0,
   OB_BULLISH,
   OB_BEARISH
};
//+------------------------------------------------------------------+
//| Liquidity sweep validation                                       |
//+------------------------------------------------------------------+
enum ENUM_SWEEP_QUALITY
{
   SWEEP_INVALID = 0,
   SWEEP_WEAK,
   SWEEP_VALID,
   SWEEP_STRONG
};
#endif

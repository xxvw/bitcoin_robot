#property copyright "Yuuto Tokuhara"
#property link      ""
#property version   "0.01"
#property strict

input group "Environment"
static input long ENV_MAGIC = 12345; // Magic Number
static input string ENV_COMMENT = "BTC Trader"; // Comment

input group "Trade Settings"
input int ENV_TP = 55000; // Take Profit Points
input int ENV_SL = 5000000; // Stop Loss Points
input int ENV_MARTIN_PIPS = 150000; // Martingale Points
input double ENV_MARTIN_MULTIPLY = 1.05; // Martingale Points Multiply
input bool ENV_TP_RECOVER_ACTIVE = true; // TP Recovery Mode
input double ENV_TP_RECOVER = 0.9; // TP Recovery Multiply

input group "Lot Settings"
input double ENV_LOT1 = 0.01; // Initial Lots
input double ENV_LOT2 = 0.01; // 2nd Position Lots
input double ENV_LOT3 = 0.02; // 3rd Position Lots
input double ENV_LOT4 = 0.02; // 4th Position Lots
input double ENV_LOT5 = 0.03; // 5th Position Lots
input double ENV_LOT6 = 0.04; // 6th Position Lots
input double ENV_LOT7 = 0.06; // 7th Position Lots
input double ENV_LOT8 = 0.08; // 8th Position Lots

input group "Lot Adjust Settings"
input bool ENV_AUTOLOT = false; // Auto Lot Adjust
input double ENV_BALSTEP = 1000.0; // Adjust Balance Step

#include <Trade\Trade.mqh>
#include <ytLib.mqh>

CTrade trade;

int OnInit() {
   trade.SetExpertMagicNumber(ENV_MAGIC);
   Comment("BTC Trader Active");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   Comment("");
}

double getLots(double lots) {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   int adjust = 1;
   if (ENV_AUTOLOT == true) {
      adjust = MathFloor(bal / ENV_BALSTEP);
   }
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots =MathFloor(lots/lotStep)*lotStep;
   if(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT) != 0) {
      double maxLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
      if (lots*adjust > maxLots) {
         return maxLots;
      }
   }
   return lots*adjust;
}

void OnTick() {

   double maV1 = YTL_getMA(20, MODE_SMA, PERIOD_CURRENT);
   double maV2 = YTL_getMA(60, MODE_SMA, PERIOD_CURRENT);
   double maV3 = YTL_getMA(110, MODE_SMA, PERIOD_CURRENT);
   double BBUpper = YTL_getBB_Upper(14, 2.0, PERIOD_CURRENT);
   double BBLower = YTL_getBB_Lower(14, 2.0, PERIOD_CURRENT);
   
   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   
   double Ask=last_tick.ask;
   double Bid=last_tick.bid;
   
   // 前回のTickでのmaV1とmaV2の値を保存するためのstatic変数
   static double prevMaV1 = 0;
   static double prevMaV2 = 0;
   static MqlTick prevTick;
   static int prevPos = 0;
   
   //Comment("MA20: ", maV1, "\nMA60: ", maV2, "\nMA110: ", maV3, "\nBBUpper: ", BBUpper, "\nBBLower: ", BBLower, "\nPositionsTotal: ", PositionsTotal(), "\nYTLgetBuy: ", YTL_getPositions(ENV_MAGIC, POSITION_TYPE_BUY), "\nisNanpinBuy: ", is_nanpin(ORDER_TYPE_BUY));
      // maV3の上にmaV1, maV2がある場合
         if (maV1 > maV3 && maV2 > maV3 && YTL_getPositions(ENV_MAGIC, POSITION_TYPE_SELL) == 0) {
            // デッドクロスを検出
            if (prevMaV1 > prevMaV2 && maV1 < maV2 && maV1 < BBUpper) {
               // Sellエントリー
               int pos = YTL_getPositions(ENV_MAGIC, POSITION_TYPE_SELL);
               double tp = Bid - (ENV_TP * MathPow(ENV_TP_RECOVER, pos)) * _Point;
               if (ENV_TP_RECOVER_ACTIVE == false) {
                  tp = Bid - ENV_TP * _Point;
               }
               trade.Sell(getLots(ENV_LOT1), NULL, Bid, 0.0, tp, ENV_COMMENT);
            }
         }
      // maV3の下にmaV1, maV2がある場合
      else if (maV1 < maV3 && maV2 < maV3 && YTL_getPositions(ENV_MAGIC, POSITION_TYPE_BUY) == 0) {
         // ゴールデンクロスを検出
         if (prevMaV1 < prevMaV2 && maV1 > maV2 && maV1 > BBLower) {
            // Buyエントリー
            int pos = YTL_getPositions(ENV_MAGIC, POSITION_TYPE_BUY);
            double tp = Ask + (ENV_TP * MathPow(ENV_TP_RECOVER, pos)) * _Point;
            if (ENV_TP_RECOVER_ACTIVE == false) {
               tp = Ask + ENV_TP * _Point;
            }
            trade.Buy(getLots(ENV_LOT1), NULL, Ask, 0.0, tp, ENV_COMMENT);
         }
      }
   
   // 現在のmaV1とmaV2の値を保存
   prevMaV1 = maV1;
   prevMaV2 = maV2;
}

void OnTrade() {
   if (YTL_getPositions(ENV_MAGIC, POSITION_TYPE_BUY) == 0) {
      YTL_deleteOrders(ENV_MAGIC, ORDER_TYPE_BUY_LIMIT);
   }
   if (YTL_getPositions(ENV_MAGIC, POSITION_TYPE_SELL) == 0) {
      YTL_deleteOrders(ENV_MAGIC, ORDER_TYPE_SELL_LIMIT);
   }
   if (PositionsTotal() >= 1) {
      if (YTL_getPositions(ENV_MAGIC, POSITION_TYPE_BUY) >= 1 && YTL_getOrders(ENV_MAGIC, ORDER_TYPE_BUY_LIMIT) < 1) {
         int pos = YTL_getPositions(ENV_MAGIC, POSITION_TYPE_BUY);
         double tp = YTL_getAvgPrice(ENV_MAGIC, POSITION_TYPE_BUY) + (ENV_TP * MathPow(ENV_TP_RECOVER, pos)) * _Point;
         if (ENV_TP_RECOVER_ACTIVE == false) {
            tp = YTL_getAvgPrice(ENV_MAGIC, POSITION_TYPE_BUY) + ENV_TP * _Point;
         }
         double sl = YTL_getAvgPrice(ENV_MAGIC, POSITION_TYPE_BUY) - ENV_SL * _Point;
         double next = YTL_getLastPrice(ENV_MAGIC, ORDER_TYPE_BUY) - (ENV_MARTIN_PIPS * (pos * ENV_MARTIN_MULTIPLY)) * _Point;
         
         switch(pos) {
            case 1:
               trade.BuyLimit(getLots(ENV_LOT2), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 2:
               trade.BuyLimit(getLots(ENV_LOT3), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 3:
               trade.BuyLimit(getLots(ENV_LOT4), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 4:
               trade.BuyLimit(getLots(ENV_LOT5), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
               
            case 5:
               trade.BuyLimit(getLots(ENV_LOT6), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 6:
               trade.BuyLimit(getLots(ENV_LOT7), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 7:
               trade.BuyLimit(getLots(ENV_LOT8), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
               
            default:
               break;
         }
         
         YTL_setTpForAll(ENV_MAGIC, POSITION_TYPE_BUY, tp);
         YTL_setSlForAll(ENV_MAGIC, POSITION_TYPE_BUY, sl);
      }
      if (YTL_getPositions(ENV_MAGIC, POSITION_TYPE_SELL) >= 1 && YTL_getOrders(ENV_MAGIC, ORDER_TYPE_SELL_LIMIT) < 1) {
         int pos = YTL_getPositions(ENV_MAGIC, POSITION_TYPE_SELL);
         double tp = YTL_getAvgPrice(ENV_MAGIC, POSITION_TYPE_SELL) - (ENV_TP * MathPow(ENV_TP_RECOVER, pos)) * _Point;
         if (ENV_TP_RECOVER_ACTIVE == false) {
            tp = YTL_getAvgPrice(ENV_MAGIC, POSITION_TYPE_SELL) - ENV_TP * _Point;
         }
         double sl = YTL_getAvgPrice(ENV_MAGIC, POSITION_TYPE_SELL) + ENV_SL * _Point;
         double next = YTL_getLastPrice(ENV_MAGIC, ORDER_TYPE_SELL) + (ENV_MARTIN_PIPS * (pos * ENV_MARTIN_MULTIPLY)) * _Point;
         
         switch(pos) {
            case 1:
               trade.SellLimit(getLots(ENV_LOT2), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 2:
               trade.SellLimit(getLots(ENV_LOT3), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 3:
               trade.SellLimit(getLots(ENV_LOT4), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 4:
               trade.SellLimit(getLots(ENV_LOT5), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
               
            case 5:
               trade.SellLimit(getLots(ENV_LOT6), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 6:
               trade.SellLimit(getLots(ENV_LOT7), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
            
            case 7:
               trade.SellLimit(getLots(ENV_LOT8), next, NULL, 0.0, 0.0, 0, 0, ENV_COMMENT);
               break;
               
            default:
               break;
         }
         
         YTL_setTpForAll(ENV_MAGIC, POSITION_TYPE_SELL, tp);
         YTL_setSlForAll(ENV_MAGIC, POSITION_TYPE_SELL, sl);
      }
   }
}

bool is_nanpin(ENUM_ORDER_TYPE side)
{
   double lastEntryPrice = YTL_getLastPrice(ENV_MAGIC, side);
   double nanpinThreshold = lastEntryPrice + (side == 0 ? -1 : 1) * ENV_MARTIN_PIPS * _Point;

   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   double currentPrice = (side == 0) ? tick.bid : tick.ask;

   if((side == 0 && currentPrice < nanpinThreshold) || (side == 1 && currentPrice > nanpinThreshold))
   {
      return true;
   }

   return false;
}

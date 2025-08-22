// MoneyManagement.mqh
// مدیریت پول، ریسک و باز کردن معاملات - برای متاتریدر ۵ بهینه‌سازی شده با چک‌های دقیق.
// محاسبات لات بر اساس ریسک درصد و فاصله SL.
// استفاده از g_Weightها برای نرمال‌سازی.

// جلوگیری از تکرار
#ifndef MONEY_MANAGEMENT_MQH
#define MONEY_MANAGEMENT_MQH

#include "Settings.mqh" // تنظیمات
#include "Logging.mqh" // لاگینگ
#include <Trade\Trade.mqh> // لایبرری تجارت

extern double g_peak_equity; // اکسترن اوج اکویتی از اصلی

// CalculateLotSize: محاسبه حجم لات بر اساس ریسک و فاصله SL
double CalculateLotSize(string symbol, double risk_percent, double sl_distance_price)
{
   Log("محاسبه حجم لات برای " + symbol + " با ریسک " + DoubleToString(risk_percent, 2) + "% و فاصله SL " + DoubleToString(sl_distance_price, _Digits));
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP); // گام لات نماد
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE); // ارزش تیکر
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT); // اندازه نقطه

   if(point == 0 || tick_value == 0 || sl_distance_price <= 0) // چک مقادیر نامعتبر
   {
      LogError("اطلاعات نماد نامعتبر یا فاصله SL برای " + symbol);
      return 0.0;
   }

   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * risk_percent / 100.0; // مقدار ریسک مطلق
   double loss_per_lot = (sl_distance_price / point) * tick_value; // ضرر per لات استاندارد

   if(loss_per_lot <= 0) // چک ضرر صفر
   {
      LogError("ضرر per لات نامعتبر (" + DoubleToString(loss_per_lot, 2) + ") برای " + symbol);
      return 0.0;
   }

   double lots = risk_amount / loss_per_lot; // لات خام
   lots = MathFloor(lots / lot_step) * lot_step; // تنظیم به گام نماد
   Log("حجم لات محاسبه شده: " + DoubleToString(lots, 2));
   return lots;
}

// IsPortfolioDrawdownExceeded: چک افت بیش از حد
bool IsPortfolioDrawdownExceeded()
{
   double current_dd = CalculateCurrentDrawdown(); // محاسبه
   LogDrawdown(current_dd); // لاگ
   bool exceeded = current_dd > Inp_MaxPortfolioDrawdown; // مقایسه
   if (exceeded) Log("افت سرمایه بیش از حد تشخیص داده شد: " + DoubleToString(current_dd * 100, 2) + "%");
   return exceeded;
}

// CalculateCurrentDrawdown: محاسبه افت فعلی از اوج
double CalculateCurrentDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY); // اکویتی فعلی
   if (equity > g_peak_equity) g_peak_equity = equity; // به‌روزرسانی اوج
   double dd = (g_peak_equity > 0) ? (g_peak_equity - equity) / g_peak_equity : 0.0; // فرمول افت
   Log("افت فعلی محاسبه شد: " + DoubleToString(dd * 100, 2) + "% با اوج اکویتی " + DoubleToString(g_peak_equity, 2));
   return dd;
}

// OpenTrade: باز کردن معامله با چک‌های ایمنی
void OpenTrade(string symbol, SIGNAL sig, int engine_id, int atr_handle)
{
   if (sig == SIGNAL_NONE) { Log("بدون سیگنال برای باز کردن معامله در " + symbol); return; }

   // چک پوزیشن باز موجود با همان مجیک - جلوگیری از duplicate
   ulong magic_number_to_check = Inp_BaseMagicNumber + engine_id;
   if(PositionSelectByMagic(symbol, magic_number_to_check))
   {
      Log("پوزیشن باز موجود برای موتور " + (engine_id == 1 ? "کنسی" : "هاپلیت") + " روی نماد " + symbol + ". معامله جدید باز نشد.");
      return;
   }

   Log("تلاش برای باز کردن معامله در " + symbol + " از موتور " + (engine_id == 1 ? "کنسی" : "هاپلیت"));
   if (atr_handle == INVALID_HANDLE) { LogError("هندل ATR نامعتبر برای " + symbol); return; }
   double atr_value[1]; // ATR
   if (CopyBuffer(atr_handle, 0, 1, 1, atr_value) <= 0) { LogError("خطا در کپی ATR برای باز کردن معامله در " + symbol); return; } // ایندکس ۱ برای کندل قبلی
   double sl_distance = 0.0; // فاصله SL
   if (engine_id == 1)
   {
      sl_distance = atr_value[0] * Inp_Kensei_ATR_Multiplier;
      Log("فاصله SL محاسبه شده برای کنسی: " + DoubleToString(sl_distance, _Digits));
   }
   else
   {
      sl_distance = atr_value[0] * Inp_Hoplite_StopLoss_ATR_Multiplier;
      Log("فاصله SL محاسبه شده برای هاپلیت: " + DoubleToString(sl_distance, _Digits));
   }
   double weight = (engine_id == 1) ? g_Kensei_Weight : g_Hoplite_Weight; // استفاده از وزن نرمال‌شده
   double risk_percent = 1.0 * weight; // ریسک ۱٪ ضربدر وزن
   Log("درصد ریسک محاسبه شده: " + DoubleToString(risk_percent, 2) + "%");
   double lots = CalculateLotSize(symbol, risk_percent, sl_distance); // محاسبه لات
   if (lots <= 0) { LogError("حجم لات نامعتبر برای " + symbol); return; }
   ENUM_ORDER_TYPE dir = (sig == SIGNAL_LONG) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; // جهت
   double open_price = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID); // قیمت بازار
   double sl = (dir == ORDER_TYPE_BUY) ? open_price - sl_distance : open_price + sl_distance; // SL
   double tp = 0.0; // TP
   if (Inp_ExitLogic == EXIT_RRR)
   {
      tp = (dir == ORDER_TYPE_BUY) ? open_price + (sl_distance * Inp_RiskRewardRatio) : open_price - (sl_distance * Inp_RiskRewardRatio);
      Log("TP محاسبه شده برای RRR: " + DoubleToString(tp, _Digits));
   }
   ulong magic = Inp_BaseMagicNumber + engine_id; // مجیک
   string comment = COMMENT_PREFIX + (engine_id == 1 ? "Kensei" : "Hoplite"); // کامنت
   CTrade trade; // شیء
   trade.SetExpertMagicNumber(magic); // تنظیم مجیک
   if (trade.PositionOpen(symbol, dir, lots, open_price, sl, tp, comment)) // باز کردن
      LogOpenTrade(symbol, (sig == SIGNAL_LONG ? "خرید" : "فروش"), lots, sl, tp); // لاگ موفق
   else
      LogError("خطا در باز کردن معامله: " + IntegerToString(trade.ResultRetcode())); // لاگ خطا
}

// پایان
#endif

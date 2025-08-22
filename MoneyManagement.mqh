// MoneyManagement.mqh
// این فایل مدیریت پول و ریسک را پیاده‌سازی می‌کند، شامل محاسبه حجم، چک DD و باز کردن معاملات.

#ifndef MONEY_MANAGEMENT_MQH  // جلوگیری از تعریف مجدد
#define MONEY_MANAGEMENT_MQH  // تعریف گارد

#include "Settings.mqh"  // شامل تنظیمات: مانند وز‌ن‌ها و DD max
#include "Logging.mqh"  // شامل لاگینگ: برای ثبت محاسبات
#include "Engine_Kensei.mqh"  // شامل Kensei: وابستگی
#include "Engine_Hoplite.mqh"  // شامل Hoplite: وابستگی

#include <Trade\Trade.mqh>  // شامل کلاس CTrade: برای عملیات معاملاتی مانند PositionOpen

extern double g_peak_equity;  // اعلام خارجی g_peak_equity: تعریف‌شده در فایل اصلی برای دسترسی

// تابع CalculateLotSize: محاسبه حجم لات بر اساس ریسک و فاصله SL
double CalculateLotSize(string symbol, double risk_percent, double sl_pips)  // پارامترها: نماد، درصد ریسک، پیپ‌های SL - بازگشت حجم
{
   Log("محاسبه حجم لات برای " + symbol + " با ریسک " + DoubleToString(risk_percent, 2) + "% و SL " + DoubleToString(sl_pips, 1) + " پیپ");  // ثبت لاگ ورودی‌ها
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);  // دریافت حداقل گام حجم نماد
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);  // ارزش هر تیک (پیپ) به پول حساب
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);  // اندازه پوینت (کوچک‌ترین واحد قیمت)
   if(point == 0 || tick_value == 0)  // چک جلوگیری از تقسیم بر صفر یا مقادیر نامعتبر
   {
      LogError("اطلاعات نماد " + symbol + " برای محاسبه حجم نامعتبر است.");  // ثبت خطا
      return 0.0;  // بازگشت حجم نامعتبر
   }
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * risk_percent / 100.0;  // محاسبه مبلغ ریسک بر اساس بالانس
   double sl_distance_points = sl_pips * 10;  // تبدیل پیپ به پوینت: برای جفت‌ارزهای 5 رقمی معمولاً *10
   long digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);  // دریافت تعداد ارقام اعشاری نماد
   if(digits == 3 || digits == 5) sl_distance_points = sl_pips * 10;  // تنظیم برای نمادهای 3 یا 5 رقمی (مانند JPY یا استاندارد)
   else sl_distance_points = sl_pips;  // برای دیگر نمادها مانند شاخص‌ها
   double sl_in_money = (sl_distance_points * point) * (tick_value / point);  // محاسبه ارزش مالی SL: فاصله * ارزش پوینت
   if (sl_in_money == 0)  // چک صفر بودن ارزش SL
   {
      LogError("فاصله SL محاسبه شده برای " + symbol + " صفر است. حجم قابل محاسبه نیست.");  // ثبت خطا
      return 0.0;  // بازگشت نامعتبر
   }
   double lots = risk_amount / sl_in_money;  // محاسبه حجم خام: ریسک / ارزش SL
   lots = MathFloor(lots / lot_step) * lot_step;  // گرد کردن به پایین بر اساس گام حجم: برای سازگاری با بروکر
   Log("حجم محاسبه شده: " + DoubleToString(lots, 2));  // ثبت لاگ نتیجه
   return lots;  // بازگشت حجم نهایی
}

// تابع IsPortfolioDrawdownExceeded: چک اگر DD بیش از حد مجاز باشد
bool IsPortfolioDrawdownExceeded()  // بدون پارامتر - بازگشت true اگر بیش از حد
{
   double current_dd = CalculateCurrentDrawdown();  // محاسبه DD فعلی
   LogDrawdown(current_dd);  // ثبت لاگ DD
   bool exceeded = current_dd > Inp_MaxPortfolioDrawdown;  // مقایسه با حد مجاز
   if (exceeded) Log("افت سرمایه بیش از حد مجاز تشخیص داده شد: " + DoubleToString(current_dd * 100, 2) + "%");  // ثبت هشدار اگر بیش از حد
   return exceeded;  // بازگشت نتیجه
}

// تابع CalculateCurrentDrawdown: محاسبه DD فعلی بر اساس اوج اکویتی
double CalculateCurrentDrawdown()  // بدون پارامتر - بازگشت DD به صورت اعشاری
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);  // دریافت اکویتی فعلی
   if (equity > g_peak_equity) g_peak_equity = equity;  // بروزرسانی اوج اگر اکویتی جدید بالاتر باشد
   double dd = (g_peak_equity > 0) ? (g_peak_equity - equity) / g_peak_equity : 0.0;  // فرمول DD: (اوج - فعلی) / اوج - چک تقسیم بر صفر
   Log("محاسبه DD فعلی: " + DoubleToString(dd * 100, 2) + "% با اوج اکویتی " + DoubleToString(g_peak_equity, 2));  // ثبت لاگ محاسبه
   return dd;  // بازگشت DD
}

// تابع OpenTrade: باز کردن معامله جدید با محاسبه حجم و تنظیم SL/TP - هندل ATR را دریافت می‌کند
void OpenTrade(string symbol, SIGNAL sig, int engine_id, int atr_handle)  // پارامترها: نماد، سیگنال، ID موتور، هندل ATR
{
   if (sig == SIGNAL_NONE) { Log("هیچ سیگنالی برای باز کردن معامله در " + symbol); return; }  // اگر بدون سیگنال، خروج
   Log("تلاش برای باز کردن معامله در " + symbol + " از موتور " + (engine_id == 1 ? "Kensei" : "Hoplite"));  // ثبت لاگ تلاش
   if (atr_handle == INVALID_HANDLE) { LogError("هندل ATR نامعتبر برای " + symbol); return; }  // چک هندل
   double sl_distance = 0.0;  // فاصله SL اولیه
   double atr_value[1];  // بافر ATR
   if (CopyBuffer(atr_handle, 0, 0, 1, atr_value) <= 0) { LogError("خطا در کپی ATR برای باز کردن معامله در " + symbol); return; }  // کپی ATR فعلی
   if (engine_id == 1)  // اگر موتور Kensei
   {
      sl_distance = atr_value[0] * Inp_Kensei_ATR_Multiplier;  // محاسبه فاصله SL بر اساس ATR و ضریب Kensei
      Log("فاصله SL محاسبه شده برای Kensei: " + DoubleToString(sl_distance, _Digits));  // ثبت لاگ
   }
   else  // اگر موتور Hoplite
   {
      sl_distance = atr_value[0] * Inp_Hoplite_StopLoss_ATR_Multiplier;  // محاسبه فاصله با ضریب Hoplite
      Log("فاصله SL محاسبه شده برای Hoplite: " + DoubleToString(sl_distance, _Digits));  // ثبت لاگ
   }
   double weight = (engine_id == 1) ? Inp_Kensei_Weight : Inp_Hoplite_Weight;  // انتخاب وزن بر اساس موتور
   double risk_percent = 1.0 * weight;  // درصد ریسک پایه 1% ضربدر وزن
   Log("درصد ریسک محاسبه شده: " + DoubleToString(risk_percent, 2) + "%");  // ثبت لاگ ریسک
   double sl_pips = sl_distance / _Point;  // تبدیل فاصله به پیپ
   double lots = CalculateLotSize(symbol, risk_percent, sl_pips);  // محاسبه حجم
   if (lots <= 0) { LogError("حجم لات نامعتبر برای " + symbol); return; }  // اگر حجم نامعتبر، خروج
   ENUM_ORDER_TYPE dir = (sig == SIGNAL_LONG) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;  // تعیین نوع سفارش: خرید یا فروش
   double open_price = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);  // قیمت باز کردن: Ask برای خرید، Bid برای فروش
   double sl = (dir == ORDER_TYPE_BUY) ? open_price - sl_distance : open_price + sl_distance;  // تنظیم SL: زیر قیمت برای خرید، بالای قیمت برای فروش
   double tp = 0.0;  // TP اولیه 0 (بدون TP)
   if (Inp_ExitLogic == EXIT_RRR)  // اگر خروج RRR
   {
      tp = (dir == ORDER_TYPE_BUY) ? open_price + (sl_distance * Inp_RiskRewardRatio) : open_price - (sl_distance * Inp_RiskRewardRatio);  // محاسبه TP: فاصله SL ضربدر نسبت
      Log("TP محاسبه شده برای RRR: " + DoubleToString(tp, _Digits));  // ثبت لاگ TP
   }
   ulong magic = Inp_BaseMagicNumber + engine_id;  // مجیک نامبر: پایه + ID موتور برای تمایز
   string comment = COMMENT_PREFIX + (engine_id == 1 ? "Kensei" : "Hoplite");  // کامنت: پیشوند + نام موتور
   CTrade trade;  // ایجاد CTrade
   trade.SetExpertMagicNumber(magic);  // تنظیم مجیک نامبر در CTrade
   if (trade.PositionOpen(symbol, dir, lots, open_price, sl, tp, comment))  // باز کردن موقعیت: با قیمت بازار (open_price به جای 0 برای دقت)
      LogOpenTrade(symbol, (sig == SIGNAL_LONG ? "خرید" : "فروش"), lots, sl, tp);  // ثبت موفقیت
   else
      LogError("خطا در باز کردن معامله: " + IntegerToString(trade.ResultRetcode()));  // ثبت خطا با کد
}

#endif  // پایان گارد

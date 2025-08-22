// Engine_Hoplite.mqh
// این فایل موتور دفاعی Hoplite را پیاده‌سازی می‌کند که بر اساس استراتژی بازگشت به میانگین کار می‌کند. شامل تولید سیگنال و مدیریت خروج است.

#ifndef ENGINE_HOPLITE_MQH  // جلوگیری از تعریف مجدد هدر
#define ENGINE_HOPLITE_MQH  // تعریف گارد

#include "Settings.mqh"  // شامل تنظیمات: دسترسی به ورودی‌ها مانند دوره‌ها و سطوح
#include "Logging.mqh"  // شامل لاگینگ: برای ثبت رویدادها و سیگنال‌ها
#include "MoneyManagement.mqh"  // شامل مدیریت پول: برای محاسبات ریسک در خروج
#include "Engine_Kensei.mqh"  // شامل موتور Kensei: برای وابستگی‌های احتمالی (اگر لازم باشد)

// تابع GetHopliteSignal: تولید سیگنال بر اساس اندیکاتورهای BB، RSI و ADX - هندل‌ها را دریافت می‌کند تا از بازسازی اندیکاتور جلوگیری شود
SIGNAL GetHopliteSignal(string symbol, int bb_handle, int rsi_handle, int adx_handle)  // پارامترها: نماد و هندل اندیکاتورها - بازگشت SIGNAL
{
   Log("شروع بررسی سیگنال Hoplite برای نماد: " + symbol);  // ثبت لاگ شروع بررسی: برای پیگیری فرآیند
   if (bb_handle == INVALID_HANDLE) { LogError("هندل BB نامعتبر برای " + symbol); return SIGNAL_NONE; }  // چک هندل BB: اگر نامعتبر، بدون سیگنال و خطا
   if (rsi_handle == INVALID_HANDLE) { LogError("هندل RSI نامعتبر برای " + symbol); return SIGNAL_NONE; }  // چک هندل RSI
   if (adx_handle == INVALID_HANDLE) { LogError("هندل ADX نامعتبر برای " + symbol); return SIGNAL_NONE; }  // چک هندل ADX
   double bb_upper[1], bb_lower[1], bb_mid[1];  // بافرهای تک‌عنصری برای باندهای بولینگر: برای ذخیره مقادیر فعلی
   double rsi[1], adx[1];  // بافرهای RSI و ADX: برای مقادیر فعلی
   double close[1];  // بافر قیمت بسته فعلی: برای چک شرط‌ها
   if (CopyBuffer(bb_handle, 0, 0, 1, bb_mid) <= 0) { LogError("خطا در کپی BB میانی برای " + symbol); return SIGNAL_NONE; }  // کپی خط میانی BB: اگر شکست، بدون سیگنال
   if (CopyBuffer(bb_handle, 1, 0, 1, bb_upper) <= 0) { LogError("خطا در کپی BB بالایی برای " + symbol); return SIGNAL_NONE; }  // کپی باند بالایی
   if (CopyBuffer(bb_handle, 2, 0, 1, bb_lower) <= 0) { LogError("خطا در کپی BB پایینی برای " + symbol); return SIGNAL_NONE; }  // کپی باند پایینی
   if (CopyBuffer(rsi_handle, 0, 1, 1, rsi) <= 0) { LogError("خطا در کپی RSI برای " + symbol); return SIGNAL_NONE; }  // کپی مقدار RSI (کندل قبلی برای جلوگیری از lookahead)
   if (CopyBuffer(adx_handle, 0, 1, 1, adx) <= 0) { LogError("خطا در کپی ADX برای " + symbol); return SIGNAL_NONE; }  // کپی مقدار ADX
   if (CopyClose(symbol, Inp_Hoplite_Timeframe, 0, 1, close) < 1) { LogError("خطا در کپی قیمت بسته فعلی برای " + symbol); return SIGNAL_NONE; }  // کپی قیمت بسته فعلی
   if (adx[0] >= Inp_Hoplite_ADX_Threshold)  // چک فیلتر رژیم بازار: اگر ADX بالا، بازار رونددار است و سیگنال نده
   {
      Log("بازار رونددار تشخیص داده شد (ADX بالا) - بدون سیگنال برای " + symbol);  // ثبت لاگ فیلتر
      return SIGNAL_NONE;  // بازگشت بدون سیگنال
   }
   if (close[0] < bb_lower[0] && rsi[0] < Inp_Hoplite_RSI_Oversold)  // شرط سیگنال خرید: قیمت زیر باند پایین و RSI در اشباع فروش
   {
      LogSignal(symbol, "Hoplite", "خرید");  // ثبت لاگ سیگنال خرید
      return SIGNAL_LONG;  // بازگشت سیگنال خرید
   }
   if (close[0] > bb_upper[0] && rsi[0] > Inp_Hoplite_RSI_Overbought)  // شرط سیگنال فروش: قیمت بالای باند بالا و RSI در اشباع خرید
   {
      LogSignal(symbol, "Hoplite", "فروش");  // ثبت لاگ سیگنال فروش
      return SIGNAL_SHORT;  // بازگشت سیگنال فروش
   }
   Log("هیچ سیگنالی در Hoplite برای " + symbol);  // ثبت لاگ عدم سیگنال
   return SIGNAL_NONE;  // بازگشت بدون سیگنال اگر هیچ شرطی برقرار نباشد
}

// تابع ManageHopliteExit: مدیریت خروج معاملات Hoplite بر اساس منطق انتخابی - هندل BB را دریافت می‌کند
void ManageHopliteExit(ulong ticket, int bb_handle)  // پارامترها: تیکت معامله و هندل BB
{
   Log("شروع مدیریت خروج Hoplite برای تیکت: " + IntegerToString(ticket));  // ثبت لاگ شروع
   if (!PositionSelectByTicket(ticket)) { LogError("خطا در انتخاب موقعیت برای خروج Hoplite"); return; }  // انتخاب موقعیت توسط تیکت: اگر شکست، خطا و خروج
   string symbol = PositionGetString(POSITION_SYMBOL);  // دریافت نماد موقعیت
   long type = PositionGetInteger(POSITION_TYPE);  // دریافت نوع موقعیت (POSITION_TYPE_BUY یا POSITION_TYPE_SELL)
   if (Inp_ExitLogic == EXIT_DYNAMIC)  // اگر منطق خروج دینامیک انتخاب شده باشد
   {
      if (bb_handle == INVALID_HANDLE) { LogError("هندل BB نامعتبر برای خروج در " + symbol); return; }  // چک هندل BB
      double bb_mid[1];  // بافر برای خط میانی BB فعلی
      if (CopyBuffer(bb_handle, 0, 0, 1, bb_mid) <= 0) { LogError("خطا در کپی BB برای خروج در " + symbol); return; }  // کپی خط میانی
      double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);  // قیمت فعلی بازار بر اساس نوع
      bool close_cond = (type == POSITION_TYPE_BUY && current_price >= bb_mid[0]) || (type == POSITION_TYPE_SELL && current_price <= bb_mid[0]);  // شرط بستن: رسیدن به خط میانی
      if (close_cond)  // اگر شرط برقرار باشد
      {
         CTrade trade;  // ایجاد شیء CTrade برای بستن
         if (trade.PositionClose(ticket, 3))  // بستن موقعیت با slippage 3
            LogCloseTrade(ticket, "رسیدن به خط میانی BB");  // ثبت لاگ موفقیت
         else
            LogError("خطا در بستن موقعیت دینامیک برای تیکت " + IntegerToString(ticket) + ": " + IntegerToString(trade.ResultRetcode()));  // ثبت خطا
      }
      else
      {
         Log("شرط بستن دینامیک برای تیکت " + IntegerToString(ticket) + " برقرار نیست.");  // ثبت لاگ عدم شرط
      }
   }
   else if (Inp_ExitLogic == EXIT_RRR)  // اگر منطق خروج RRR باشد
   {
      Log("خروج RRR برای Hoplite - چک TP برای تیکت " + IntegerToString(ticket));  // ثبت لاگ (چک TP در کد دیگر پیاده‌سازی می‌شود)
   }
   Log("پایان مدیریت خروج Hoplite برای تیکت: " + IntegerToString(ticket));  // ثبت لاگ پایان
}

#endif  // پایان گارد تعریف

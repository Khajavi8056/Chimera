// Engine_Hoplite.mqh
// این فایل موتور دفاعی هاپلیت را پیاده‌سازی می‌کند که از استراتژی بازگشت به میانگین (mean-reversion) استفاده می‌کند.
// بر اساس بولینگر بندز، RSI و ADX برای تشخیص رنج و بیش‌خرید/بیش‌فروش.
// برای متاتریدر ۵ بهینه‌سازی شده با چک‌های دقیق برای هندل‌ها و داده‌ها.
// تمام عملیات با لاگینگ برای آموزش و دیباگ.

// جلوگیری از تکرار تعریف هدر
#ifndef ENGINE_HOPLITE_MQH
#define ENGINE_HOPLITE_MQH

// اینکلود فایل‌های لازم - وابستگی‌ها حداقل نگه داشته شده
#include "Settings.mqh" // تنظیمات و enumها
#include "Logging.mqh" // لاگینگ
#include "MoneyManagement.mqh" // مدیریت معامله (برای SIGNAL)

// تابع GetHopliteSignal: تولید سیگنال برای هاپلیت - فقط در بازار رنج
SIGNAL GetHopliteSignal(string symbol, int bb_handle, int rsi_handle, int adx_handle)
{
   Log("شروع چک سیگنال هاپلیت برای نماد: " + symbol); // لاگ شروع برای پیگیری گام‌به‌گام
   // چک هندل‌های اندیکاتور - برای جلوگیری از crash
   if (bb_handle == INVALID_HANDLE) { LogError("هندل BB نامعتبر برای " + symbol); return SIGNAL_NONE; }
   if (rsi_handle == INVALID_HANDLE) { LogError("هندل RSI نامعتبر برای " + symbol); return SIGNAL_NONE; }
   if (adx_handle == INVALID_HANDLE) { LogError("هندل ADX نامعتبر برای " + symbol); return SIGNAL_NONE; }

   // آرایه‌های داده - اندازه ۱ برای کندل قبلی
   double bb_upper[1], bb_lower[1]; // باندها
   double rsi[1], adx[1]; // RSI و ADX
   double close[1]; // قیمت بسته شدن قبلی

   // کپی داده‌ها از بافر - ایندکس ۱ برای کندل قبلی (کامل‌شده)
   if(CopyBuffer(bb_handle, 1, 1, 1, bb_upper) <= 0) { LogError("هاپلیت: خطا در کپی باند بالا BB برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(bb_handle, 2, 1, 1, bb_lower) <= 0) { LogError("هاپلیت: خطا در کپی باند پایین BB برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(rsi_handle, 0, 1, 1, rsi) <= 0) { LogError("هاپلیت: خطا در کپی RSI برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(adx_handle, 0, 1, 1, adx) <= 0) { LogError("هاپلیت: خطا در کپی ADX برای " + symbol); return SIGNAL_NONE; }
   if(CopyClose(symbol, Inp_Hoplite_Timeframe, 1, 1, close) < 1) { LogError("هاپلیت: خطا در کپی بسته شدن قبلی برای " + symbol); return SIGNAL_NONE; }

   // چک بازار رونددار با ADX - اگر رونددار، سیگنال نده (هاپلیت برای رنج است)
   if(adx[0] >= Inp_Hoplite_ADX_Threshold)
   {
      Log("بازار رونددار تشخیص داده شد (ADX=" + DoubleToString(adx[0], 2) + ") - بدون سیگنال برای " + symbol); // لاگ دلیل
      return SIGNAL_NONE; // بازگشت بدون سیگنال
   }

   // شرط سیگنال خرید: قیمت زیر باند پایین و RSI بیش‌فروش
   if(close[0] < bb_lower[0] && rsi[0] < Inp_Hoplite_RSI_Oversold)
   {
      LogSignal(symbol, "هاپلیت", "خرید"); // لاگ سیگنال
      return SIGNAL_LONG; // سیگنال خرید
   }

   // شرط سیگنال فروش: قیمت بالای باند بالا و RSI بیش‌خرید
   if(close[0] > bb_upper[0] && rsi[0] > Inp_Hoplite_RSI_Overbought)
   {
      LogSignal(symbol, "هاپلیت", "فروش"); // لاگ سیگنال
      return SIGNAL_SHORT; // سیگنال فروش
   }
   Log("بدون سیگنال در هاپلیت برای " + symbol); // لاگ عدم سیگنال
   return SIGNAL_NONE; // بازگشت پیش‌فرض
}

// تابع ManageHopliteExit: مدیریت خروج برای پوزیشن‌های هاپلیت
void ManageHopliteExit(ulong ticket, int bb_handle)
{
   Log("شروع مدیریت خروج هاپلیت برای تیکت: " + IntegerToString(ticket)); // لاگ شروع
   if (!PositionSelectByTicket(ticket)) { LogError("خطا در انتخاب پوزیشن برای خروج هاپلیت"); return; } // انتخاب پوزیشن
   string symbol = PositionGetString(POSITION_SYMBOL); // نماد
   long type = PositionGetInteger(POSITION_TYPE); // نوع (خرید/فروش)
   if (Inp_ExitLogic == EXIT_DYNAMIC) // اگر خروج دینامیک
   {
      if (bb_handle == INVALID_HANDLE) { LogError("هندل BB نامعتبر برای خروج در " + symbol); return; } // چک هندل
      double bb_mid[1]; // خط میانی بولینگر
      if (CopyBuffer(bb_handle, 0, 0, 1, bb_mid) <= 0) { LogError("خطا در کپی BB برای خروج در " + symbol); return; } // کپی داده (ایندکس ۰ برای کندل فعلی)
      double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت فعلی
      // شرط بسته شدن: برای خرید، قیمت به خط میانی برسد یا بالاتر؛ برای فروش، پایین‌تر
      bool close_cond = (type == POSITION_TYPE_BUY && current_price >= bb_mid[0]) || (type == POSITION_TYPE_SELL && current_price <= bb_mid[0]);
      if (close_cond) // اگر شرط برقرار
      {
         CTrade trade; // شیء تجارت
         if (trade.PositionClose(ticket, 3)) // بستن با slippage 3
            LogCloseTrade(ticket, "رسیدن به خط میانی BB"); // لاگ موفق
         else
            LogError("خطا در بستن پوزیشن دینامیک برای تیکت " + IntegerToString(ticket) + ": " + IntegerToString(trade.ResultRetcode())); // لاگ خطا
      }
      else
      {
         Log("شرط بسته شدن دینامیک برقرار نیست برای تیکت " + IntegerToString(ticket)); // لاگ عدم شرط
      }
   }
   else if (Inp_ExitLogic == EXIT_RRR) // اگر خروج RRR (TP ثابت چک می‌شود توسط متاتریدر)
   {
      Log("خروج RRR برای هاپلیت - چک TP برای تیکت " + IntegerToString(ticket)); // لاگ (در عمل TP در باز کردن تنظیم شده)
   }
   Log("پایان مدیریت خروج هاپلیت برای تیکت: " + IntegerToString(ticket)); // لاگ پایان
}

// پایان گارد
#endif

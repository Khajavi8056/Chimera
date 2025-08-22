// Engine_Kensei.mqh
// این فایل موتور تهاجمی Kensei را پیاده‌سازی می‌کند که بر اساس ایچیموکو روندگرا است. شامل تولید سیگنال و مدیریت خروج.

#ifndef ENGINE_KENSEI_MQH  // جلوگیری از تعریف مجدد
#define ENGINE_KENSEI_MQH  // تعریف گارد

#include "Settings.mqh"  // شامل تنظیمات: دوره‌های ایچیموکو و ATR
#include "Logging.mqh"  // شامل لاگینگ: ثبت سیگنال‌ها و خطاها
#include "MoneyManagement.mqh"  // شامل مدیریت پول: برای خروج دینامیک SL
#include "Engine_Hoplite.mqh"  // شامل موتور Hoplite: برای وابستگی‌های احتمالی

// تابع GetKenseiSignal: تولید سیگنال بر اساس شرایط ایچیموکو - هندل‌ها را دریافت می‌کند
SIGNAL GetKenseiSignal(string symbol, int ichi_handle, int atr_handle)  // پارامترها: نماد، هندل ایچیموکو و ATR
{
   Log("شروع بررسی سیگنال Kensei برای نماد: " + symbol);  // ثبت لاگ شروع
   if (ichi_handle == INVALID_HANDLE) { LogError("هندل ایچیموکو نامعتبر است برای " + symbol); return SIGNAL_NONE; }  // چک هندل ایچیموکو
   if (atr_handle == INVALID_HANDLE) { LogError("هندل ATR نامعتبر است برای " + symbol); return SIGNAL_NONE; }  // چک هندل ATR
   double tenkan[1], kijun[1], ssa[2], ssb[2];  // بافرها برای خطوط ایچیموکو: فعلی و قبلی برای چک شکست
   double atr[1];  // بافر ATR: برای نوسان (هرچند اینجا استفاده نمی‌شود، اما هندل دریافت شده)
   if (CopyBuffer(ichi_handle, 0, 1, 1, tenkan) <= 0) { LogError("خطا در کپی تنکان برای " + symbol); return SIGNAL_NONE; }  // کپی تنکان فعلی
   if (CopyBuffer(ichi_handle, 1, 1, 1, kijun) <= 0) { LogError("خطا در کپی کیجون برای " + symbol); return SIGNAL_NONE; }  // کپی کیجون فعلی
   if (CopyBuffer(ichi_handle, 2, 0, 2, ssa) <= 0) { LogError("خطا در کپی SSA برای " + symbol); return SIGNAL_NONE; }  // کپی SSA فعلی و قبلی
   if (CopyBuffer(ichi_handle, 3, 0, 2, ssb) <= 0) { LogError("خطا در کپی SSB برای " + symbol); return SIGNAL_NONE; }  // کپی SSB فعلی و قبلی
   if (CopyBuffer(atr_handle, 0, 1, 1, atr) <= 0) { LogError("خطا در کپی ATR برای " + symbol); return SIGNAL_NONE; }  // کپی ATR (کندل قبلی)
   double close[2];  // بافر قیمت بسته: فعلی و قبلی برای چک شکست ابر
   if (CopyClose(symbol, Inp_Kensei_Timeframe, 0, 2, close) < 2) { LogError("خطا در کپی قیمت بسته برای " + symbol); return SIGNAL_NONE; }  // کپی closes
   double past_closes[27];  // بافر قیمت‌های گذشته: برای محاسبه چیکو (26 کندل قبل + فعلی)
   if (CopyClose(symbol, Inp_Kensei_Timeframe, 0, 27, past_closes) < 27) { LogError("خطا در کپی قیمت‌های گذشته برای چیکو در " + symbol); return SIGNAL_NONE; }  // کپی گذشته‌ها
   double chikou_value = past_closes[0];  // مقدار چیکو: برابر قیمت بسته فعلی (برای چک با 26 کندل قبل)
   double past_highs[];  // آرایه بالاترین قیمت‌ها: برای چک فضای باز چیکو
   double past_lows[];  // آرایه پایین‌ترین قیمت‌ها: برای چک فضای باز
   ArrayResize(past_highs, Inp_Kensei_Chikou_OpenSpace);  // تغییر اندازه آرایه به تعداد مشخص‌شده در ورودی
   ArrayResize(past_lows, Inp_Kensei_Chikou_OpenSpace);  // تغییر اندازه آرایه lows
   if (CopyHigh(symbol, Inp_Kensei_Timeframe, Inp_Kensei_Kijun, Inp_Kensei_Chikou_OpenSpace, past_highs) < Inp_Kensei_Chikou_OpenSpace) { LogError("خطا در کپی بالاترین‌ها برای فضای باز چیکو در " + symbol); return SIGNAL_NONE; }  // کپی highs از کیجون به عقب
   if (CopyLow(symbol, Inp_Kensei_Timeframe, Inp_Kensei_Kijun, Inp_Kensei_Chikou_OpenSpace, past_lows) < Inp_Kensei_Chikou_OpenSpace) { LogError("خطا در کپی پایین‌ترین‌ها برای فضای باز چیکو در " + symbol); return SIGNAL_NONE; }  // کپی lows
   double future_ssa[1], future_ssb[1];  // بافر ابر آینده: برای چک صعودی/نزولی بودن ابر آینده
   if (CopyBuffer(ichi_handle, 2, -Inp_Kensei_Kijun, 1, future_ssa) <= 0) { LogError("خطا در کپی SSA آینده برای " + symbol); return SIGNAL_NONE; }  // کپی SSA آینده (منفی برای آینده)
   if (CopyBuffer(ichi_handle, 3, -Inp_Kensei_Kijun, 1, future_ssb) <= 0) { LogError("خطا در کپی SSB آینده برای " + symbol); return SIGNAL_NONE; }  // کپی SSB آینده
   bool long_cond1 = close[0] > MathMax(ssa[0], ssb[0]) && close[1] <= MathMax(ssa[1], ssb[1]);  // شرط 1 خرید: شکست ابر به بالا (فعلی بالای ابر، قبلی زیر یا داخل)
   bool long_cond2 = future_ssa[0] > future_ssb[0];  // شرط 2 خرید: ابر آینده صعودی
   bool long_cond3 = chikou_value > past_closes[26];  // شرط 3 خرید: چیکو بالای قیمت 26 کندل قبل
   bool long_cond4 = chikou_value > ArrayMaximum(past_highs, 0, WHOLE_ARRAY);  // شرط 4 خرید: فضای باز چیکو (بالای حداکثر highs گذشته)
   if (long_cond1 && long_cond2 && long_cond3 && long_cond4)  // اگر تمام شرط‌های خرید برقرار باشد
   {
      LogSignal(symbol, "Kensei", "خرید");  // ثبت لاگ سیگنال
      return SIGNAL_LONG;  // بازگشت سیگنال خرید
   }
   bool short_cond1 = close[0] < MathMin(ssa[0], ssb[0]) && close[1] >= MathMin(ssa[1], ssb[1]);  // شرط 1 فروش: شکست ابر به پایین
   bool short_cond2 = future_ssa[0] < future_ssb[0];  // شرط 2 فروش: ابر آینده نزولی
   bool short_cond3 = chikou_value < past_closes[26];  // شرط 3 فروش: چیکو پایین قیمت 26 کندل قبل
   bool short_cond4 = chikou_value < ArrayMinimum(past_lows, 0, WHOLE_ARRAY);  // شرط 4 فروش: فضای باز چیکو (پایین حداقل lows گذشته)
   if (short_cond1 && short_cond2 && short_cond3 && short_cond4)  // اگر تمام شرط‌های فروش برقرار باشد
   {
      LogSignal(symbol, "Kensei", "فروش");  // ثبت لاگ
      return SIGNAL_SHORT;  // بازگشت سیگنال فروش
   }
   Log("هیچ سیگنالی در Kensei برای " + symbol);  // ثبت لاگ عدم سیگنال
   return SIGNAL_NONE;  // بازگشت بدون سیگنال
}

// تابع ManageKenseiExit: مدیریت خروج معاملات Kensei بر اساس منطق - هندل ایچیموکو را دریافت می‌کند
void ManageKenseiExit(ulong ticket, int ichi_handle)  // پارامترها: تیکت و هندل ایچیموکو
{
   Log("شروع مدیریت خروج Kensei برای تیکت: " + IntegerToString(ticket));  // ثبت لاگ شروع
   if (!PositionSelectByTicket(ticket)) { LogError("خطا در انتخاب موقعیت برای خروج Kensei"); return; }  // انتخاب موقعیت: اگر شکست، خطا
   string symbol = PositionGetString(POSITION_SYMBOL);  // دریافت نماد
   long type = PositionGetInteger(POSITION_TYPE);  // دریافت نوع (خرید/فروش)
   if (Inp_ExitLogic == EXIT_DYNAMIC)  // اگر خروج دینامیک
   {
      if (ichi_handle == INVALID_HANDLE) { LogError("هندل ایچیموکو نامعتبر برای خروج در " + symbol); return; }  // چک هندل
      double kijun[1];  // بافر کیجون فعلی
      if (CopyBuffer(ichi_handle, 1, 1, 1, kijun) <= 0) { LogError("خطا در کپی کیجون برای خروج در " + symbol); return; }  // کپی کیجون (کندل قبلی)
      double current_sl = PositionGetDouble(POSITION_SL);  // دریافت SL فعلی موقعیت
      double new_sl = kijun[0];  // SL جدید بر اساس کیجون
      bool modify = false;  // فلگ برای تصمیم‌گیری اصلاح SL
      if (type == POSITION_TYPE_BUY && new_sl > current_sl) modify = true;  // برای خرید: اگر کیجون بالاتر از SL فعلی، بروزرسانی
      else if (type == POSITION_TYPE_SELL && new_sl < current_sl && new_sl > 0) modify = true;  // برای فروش: اگر کیجون پایین‌تر، بروزرسانی
      if (modify)  // اگر نیاز به اصلاح باشد
      {
         CTrade trade;  // ایجاد CTrade برای اصلاح
         if (trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))  // اصلاح SL (TP بدون تغییر)
            Log("به‌روزرسانی SL دینامیک برای تیکت " + IntegerToString(ticket) + " به " + DoubleToString(new_sl, _Digits));  // ثبت موفقیت
         else 
            LogError("خطا در اصلاح SL دینامیک برای تیکت " + IntegerToString(ticket) + ": " + IntegerToString(trade.ResultRetcode()));  // ثبت خطا
      }
      else
      {
         Log("هیچ تغییری در SL دینامیک برای تیکت " + IntegerToString(ticket) + " لازم نیست.");  // ثبت عدم نیاز به تغییر
      }
   }
   else if (Inp_ExitLogic == EXIT_RRR)  // اگر خروج RRR
   {
      Log("خروج RRR برای Kensei - چک TP برای تیکت " + IntegerToString(ticket));  // ثبت لاگ (چک TP در جای دیگر)
   }
   Log("پایان مدیریت خروج Kensei برای تیکت: " + IntegerToString(ticket));  // ثبت پایان
}

#endif  // پایان گارد

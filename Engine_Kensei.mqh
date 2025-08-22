// Engine_Kensei.mqh
// موتور تهاجمی روندگرا بر اساس ایچیموکو - این فایل منطق سیگنال و خروج Kensei را پیاده‌سازی می‌کند

#ifndef ENGINE_KENSEI_MQH  // بررسی برای جلوگیری از تعریف مجدد هدر - جلوگیری از کامپایل چندباره
#define ENGINE_KENSEI_MQH  // تعریف گارد برای جلوگیری از تعریف مجدد

#include <Settings.mqh>  // شامل کردن تنظیمات - دسترسی به پارامترهای ورودی
#include <Logging.mqh>  // شامل کردن سیستم لاگ - برای لاگینگ رویدادها

// تعریف enum برای سیگنال‌ها - enum برای انواع سیگنال
enum SIGNAL { SIGNAL_NONE, SIGNAL_LONG, SIGNAL_SHORT };  // سیگنال هیچ، خرید، فروش - انواع سیگنال ممکن

// تابع برای دریافت سیگنال Kensei - تولید سیگنال بر اساس شرایط ایچیموکو، هندل‌ها را به عنوان ورودی دریافت می‌کند
SIGNAL GetKenseiSignal(string symbol, int ichi_handle, int atr_handle)
{
   Log("شروع بررسی سیگنال Kensei برای نماد: " + symbol);  // لاگ شروع بررسی سیگنال - ثبت شروع فرآیند
   if (ichi_handle == INVALID_HANDLE) { LogError("هندل ایچیموکو نامعتبر است برای " + symbol); return SIGNAL_NONE; }  // چک هندل ایچیموکو معتبر - خطا اگر نامعتبر
   if (atr_handle == INVALID_HANDLE) { LogError("هندل ATR نامعتبر است برای " + symbol); return SIGNAL_NONE; }  // چک هندل ATR معتبر - خطا اگر نامعتبر
   double tenkan[1], kijun[1], ssa[2], ssb[2];  // آرایه‌ها برای داده‌های فعلی و قبلی - بافرهای ایچیموکو
   double atr[1];  // بافر ATR - برای محاسبه نوسان
   if (CopyBuffer(ichi_handle, 0, 1, 1, tenkan) <= 0) { LogError("خطا در کپی تنکان برای " + symbol); return SIGNAL_NONE; }  // کپی تنکان فعلی - دریافت داده از هندل
   if (CopyBuffer(ichi_handle, 1, 1, 1, kijun) <= 0) { LogError("خطا در کپی کیجون برای " + symbol); return SIGNAL_NONE; }  // کپی کیجون فعلی - دریافت داده از هندل
   if (CopyBuffer(ichi_handle, 2, 0, 2, ssa) <= 0) { LogError("خطا در کپی SSA برای " + symbol); return SIGNAL_NONE; }  // کپی SSA فعلی و قبلی - دریافت ابر از هندل
   if (CopyBuffer(ichi_handle, 3, 0, 2, ssb) <= 0) { LogError("خطا در کپی SSB برای " + symbol); return SIGNAL_NONE; }  // کپی SSB فعلی و قبلی - دریافت ابر از هندل
   if (CopyBuffer(atr_handle, 0, 1, 1, atr) <= 0) { LogError("خطا در کپی ATR برای " + symbol); return SIGNAL_NONE; }  // کپی ATR از هندل ورودی - دریافت نوسان
   double close[2];  // آرایه برای دو کندل آخر - قیمت‌های بسته
   if (CopyClose(symbol, Inp_Kensei_Timeframe, 0, 2, close) < 2) { LogError("خطا در کپی قیمت بسته برای " + symbol); return SIGNAL_NONE; }  // کپی قیمت بسته - دریافت closes
   double past_closes[27];  // آرایه برای قیمت‌های گذشته - برای چیکو
   if (CopyClose(symbol, Inp_Kensei_Timeframe, 0, 27, past_closes) < 27) { LogError("خطا در کپی قیمت‌های گذشته برای چیکو در " + symbol); return SIGNAL_NONE; }  // کپی گذشته - دریافت داده چیکو
   double chikou_value = past_closes[0];  // مقدار چیکو اسپن برابر قیمت فعلی - محاسبه چیکو
   double past_highs[Inp_Kensei_Chikou_OpenSpace];  // آرایه برای بالاترین‌ها - برای فضای باز
   double past_lows[Inp_Kensei_Chikou_OpenSpace];  // آرایه برای پایین‌ترین‌ها - برای فضای باز
   if (CopyHigh(symbol, Inp_Kensei_Timeframe, Inp_Kensei_Kijun, Inp_Kensei_Chikou_OpenSpace, past_highs) < Inp_Kensei_Chikou_OpenSpace) { LogError("خطا در کپی بالاترین‌ها برای فضای باز چیکو در " + symbol); return SIGNAL_NONE; }  // کپی بالاترین‌ها - دریافت highs
   if (CopyLow(symbol, Inp_Kensei_Timeframe, Inp_Kensei_Kijun, Inp_Kensei_Chikou_OpenSpace, past_lows) < Inp_Kensei_Chikou_OpenSpace) { LogError("خطا در کپی پایین‌ترین‌ها برای فضای باز چیکو در " + symbol); return SIGNAL_NONE; }  // کپی پایین‌ترین‌ها - دریافت lows
   double future_ssa[1], future_ssb[1];  // بافرهای ابر آینده - برای چک آینده
   if (CopyBuffer(ichi_handle, 2, -Inp_Kensei_Kijun, 1, future_ssa) <= 0) { LogError("خطا در کپی SSA آینده برای " + symbol); return SIGNAL_NONE; }  // کپی SSA آینده - دریافت آینده از هندل
   if (CopyBuffer(ichi_handle, 3, -Inp_Kensei_Kijun, 1, future_ssb) <= 0) { LogError("خطا در کپی SSB آینده برای " + symbol); return SIGNAL_NONE; }  // کپی SSB آینده - دریافت آینده از هندل
   bool long_cond1 = close[0] > MathMax(ssa[0], ssb[0]) && close[1] <= MathMax(ssa[1], ssb[1]);  // شرط شکست ابر کومو (کندل فعلی بالای ابر، قبلی داخل یا زیر) - چک شکست خرید
   bool long_cond2 = future_ssa[0] > future_ssb[0];  // ابر آینده صعودی - چک آینده خرید
   bool long_cond3 = chikou_value > past_closes[26];  // تایید چیکو (بالای قیمت ۲۶ کندل قبل) - چک تایید چیکو خرید
   bool long_cond4 = chikou_value > ArrayMaximum(past_highs, 0, WHOLE_ARRAY);  // فضای باز چیکو (بالای بالاترین گذشته) - چک فضای باز خرید
   if (long_cond1 && long_cond2 && long_cond3 && long_cond4) 
   {
      LogSignal(symbol, "Kensei", "خرید");  // لاگ سیگنال خرید - ثبت سیگنال
      return SIGNAL_LONG;  // بازگشت سیگنال خرید - سیگنال LONG
   }
   bool short_cond1 = close[0] < MathMin(ssa[0], ssb[0]) && close[1] >= MathMin(ssa[1], ssb[1]);  // شرط شکست ابر کومو (کندل فعلی پایین ابر، قبلی داخل یا بالای) - چک شکست فروش
   bool short_cond2 = future_ssa[0] < future_ssb[0];  // ابر آینده نزولی - چک آینده فروش
   bool short_cond3 = chikou_value < past_closes[26];  // تایید چیکو (پایین قیمت ۲۶ کندل قبل) - چک تایید چیکو فروش
   bool short_cond4 = chikou_value < ArrayMinimum(past_lows, 0, WHOLE_ARRAY);  // فضای باز چیکو (پایین پایین‌ترین گذشته) - چک فضای باز فروش
   if (short_cond1 && short_cond2 && short_cond3 && short_cond4) 
   {
      LogSignal(symbol, "Kensei", "فروش");  // لاگ سیگنال فروش - ثبت سیگنال
      return SIGNAL_SHORT;  // بازگشت سیگنال فروش - سیگنال SHORT
   }
   Log("هیچ سیگنالی در Kensei برای " + symbol);  // لاگ عدم سیگنال - ثبت عدم تولید
   return SIGNAL_NONE;  // بازگشت بدون سیگنال - NONE
}

// تابع مدیریت خروج برای Kensei - مدیریت خروج معاملات Kensei، هندل ایچیموکو را دریافت می‌کند
void ManageKenseiExit(ulong ticket, int ichi_handle)
{
   Log("شروع مدیریت خروج Kensei برای تیکت: " + IntegerToString(ticket));  // لاگ شروع مدیریت خروج - ثبت شروع
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) { LogError("خطا در انتخاب سفارش برای خروج Kensei"); return; }  // انتخاب سفارش و چک - خطا اگر شکست
   string symbol = OrderSymbol();  // نماد سفارش - دریافت نماد
   int type = OrderType();  // نوع سفارش (خرید/فروش) - دریافت نوع
   if (Inp_ExitLogic == EXIT_DYNAMIC)  // اگر خروج دینامیک - چک منطق
   {
      if (ichi_handle == INVALID_HANDLE) { LogError("هندل ایچیموکو نامعتبر برای خروج در " + symbol); return; }  // چک هندل معتبر - خطا اگر نامعتبر
      double kijun[1];  // بافر کیجون فعلی - آرایه kijun
      if (CopyBuffer(ichi_handle, 1, 1, 1, kijun) <= 0) { LogError("خطا در کپی کیجون برای خروج در " + symbol); return; }  // کپی کیجون از هندل - دریافت داده
      double current_sl = OrderStopLoss();  // SL فعلی سفارش - دریافت SL فعلی
      double new_sl = kijun[0];  // SL جدید بر اساس کیجون - تنظیم new SL
      bool modify = false;  // فلگ برای اصلاح - فلگ تغییر
      if (type == OP_BUY && new_sl > current_sl) modify = true;  // برای خرید، فقط اگر SL جدید بالاتر باشد - چک خرید
      else if (type == OP_SELL && new_sl < current_sl && new_sl > 0) modify = true;  // برای فروش، فقط اگر SL جدید پایین‌تر باشد - چک فروش
      if (modify) 
      {
         if (OrderModify(ticket, OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrBlue)) 
            Log("به‌روزرسانی SL دینامیک برای تیکت " + IntegerToString(ticket) + " به " + DoubleToString(new_sl, _Digits));  // لاگ موفقیت به‌روزرسانی - ثبت موفقیت
         else 
            LogError("خطا در اصلاح SL دینامیک برای تیکت " + IntegerToString(ticket) + ": " + IntegerToString(GetLastError()));  // لاگ خطا در اصلاح - ثبت خطا
      }
      else
      {
         Log("هیچ تغییری در SL دینامیک برای تیکت " + IntegerToString(ticket) + " لازم نیست.");  // لاگ عدم نیاز به تغییر - ثبت عدم تغییر
      }
   }
   else if (Inp_ExitLogic == EXIT_RRR)  // اگر خروج RRR - چک منطق
   {
      Log("خروج RRR برای Kensei - چک TP برای تیکت " + IntegerToString(ticket));  // لاگ چک TP - ثبت چک
   }
   Log("پایان مدیریت خروج Kensei برای تیکت: " + IntegerToString(ticket));  // لاگ پایان مدیریت خروج - ثبت پایان
}

#endif  // پایان گارد تعریف - پایان هدر

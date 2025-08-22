// Engine_Kensei.mqh
// این فایل موتور تهاجمی کنسی را پیاده‌سازی می‌کند که از استراتژی دنبال‌کننده روند (trend-following) با ایچیموکو استفاده می‌کند.
// شرایط سیگنال دقیق چک می‌شود و برای متاتریدر ۵ بهینه‌سازی شده با مدیریت حافظه داینامیک.
// کامنت‌ها برای آموزش گام‌به‌گام نوشته شده.

// جلوگیری از تکرار تعریف هدر
#ifndef ENGINE_KENSEI_MQH
#define ENGINE_KENSEI_MQH

// اینکلود فایل‌های لازم
#include "Settings.mqh" // تنظیمات
#include "Logging.mqh" // لاگینگ
#include "MoneyManagement.mqh" // مدیریت (برای SIGNAL)

// تابع GetKenseiSignal: تولید سیگنال برای کنسی - فقط در روند قوی
SIGNAL GetKenseiSignal(string symbol, int ichi_handle, int atr_handle)
{
   Log("شروع چک سیگنال کنسی برای نماد: " + symbol); // لاگ شروع
   // چک هندل‌ها
   if (ichi_handle == INVALID_HANDLE) { LogError("هندل ایچیموکو نامعتبر برای " + symbol); return SIGNAL_NONE; }
   if (atr_handle == INVALID_HANDLE) { LogError("هندل ATR نامعتبر برای " + symbol); return SIGNAL_NONE; }

   // آرایه‌های داده برای ایچیموکو - اندازه برای کندل‌های لازم
   double tenkan[1], kijun[1], ssa[2], ssb[2]; // تنکان، کیجون، SSA، SSB
   double close[2]; // بسته شدن دو کندل اخیر
   double chikou_compare_price[1]; // قیمت مقایسه چیکو (۲۶ کندل قبل)
   double past_highs[]; // های گذشته برای فضای باز چیکو - داینامیک
   double past_lows[]; // لوهای گذشته برای فضای باز چیکو - داینامیک
   double future_ssa[1], future_ssb[1]; // SSA و SSB آینده برای چک ابر

   // کپی داده‌های ایچیموکو - ایندکس ۱ برای کندل قبلی
   if(CopyBuffer(ichi_handle, 0, 1, 1, tenkan) <= 0) { LogError("کنسی: خطا در کپی تنکان برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(ichi_handle, 1, 1, 1, kijun) <= 0) { LogError("کنسی: خطا در کپی کیجون برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(ichi_handle, 2, 1, 2, ssa) <= 0) { LogError("کنسی: خطا در کپی SSA برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(ichi_handle, 3, 1, 2, ssb) <= 0) { LogError("کنسی: خطا در کپی SSB برای " + symbol); return SIGNAL_NONE; }

   // کپی قیمت‌های بسته شدن
   if(CopyClose(symbol, Inp_Kensei_Timeframe, 1, 2, close) < 2) { LogError("کنسی: خطا در کپی قیمت‌های بسته شدن برای " + symbol); return SIGNAL_NONE; }

   // کپی قیمت مقایسه چیکو (۲۶ کندل قبل +۱ برای ایندکس)
   // شیفت ۲۶ کندل برای چیکو اسپن + ۱ برای اینکه کندل قبلی رو چک کنیم، میشه ۲۷
   if(CopyClose(symbol, Inp_Kensei_Timeframe, 27, 1, chikou_compare_price) < 1) 
   {
      LogError("کنسی: خطا در کپی قیمت گذشته برای مقایسه چیکو در " + symbol);
      return SIGNAL_NONE;
   }

   // کپی های و لوهای گذشته برای فضای باز چیکو - از موقعیت ۲۷ به عقب
   if (CopyHigh(symbol, Inp_Kensei_Timeframe, 27, Inp_Kensei_Chikou_OpenSpace, past_highs) != Inp_Kensei_Chikou_OpenSpace)
   { 
      LogError("خطا در کپی High برای فضای باز چیکو در " + symbol); 
      return SIGNAL_NONE; 
   }
   if (CopyLow(symbol, Inp_Kensei_Timeframe, 27, Inp_Kensei_Chikou_OpenSpace, past_lows) != Inp_Kensei_Chikou_OpenSpace) 
   { 
      LogError("خطا در کپی Low برای فضای باز چیکو در " + symbol); 
      return SIGNAL_NONE; 
   }

   // --- کد اصلاح شده برای خواندن صحیح ابر آینده ---
   // برای خواندن مقادیر ابر کومو که ۲۶ کندل به جلو شیفت داده شده‌اند، از ایندکس ۲۶ در CopyBuffer استفاده می‌کنیم.
   // این کار مقدار ابری که بالای کندل فعلی نمایش داده می‌شود را به ما می‌دهد.
   // ثابت Inp_Kensei_Kijun به طور پیش‌فرض 26 است و شیفت استاندارد ایچیموکو را نشان می‌دهد.
   if(CopyBuffer(ichi_handle, 2, Inp_Kensei_Kijun, 1, future_ssa) <= 0) 
   { 
      LogError("کنسی: خطا در کپی SSA آینده برای " + symbol); 
      return SIGNAL_NONE; 
   }
   if(CopyBuffer(ichi_handle, 3, Inp_Kensei_Kijun, 1, future_ssb) <= 0) 
   { 
      LogError("کنسی: خطا در کپی SSB آینده برای " + symbol); 
      return SIGNAL_NONE; 
   }

   double chikou_value = close[0]; // چیکو برابر بسته شدن قبلی است (برای مقایسه با قیمت ۲۶ کندل قبل)

   // شرط‌های سیگنال خرید: breakout بالای ابر، ابر آینده صعودی، چیکو بالای قیمت و فضای باز
   bool long_cond1 = close[0] > MathMax(ssa[0], ssb[0]) && close[1] <= MathMax(ssa[1], ssb[1]); // شرط breakout: این کندل بالای ابره ولی کندل قبلی نبوده
   bool long_cond2 = future_ssa[0] > future_ssb[0]; // ابر آینده صعودی است
   bool long_cond3 = chikou_value > chikou_compare_price[0]; // چیکو بالای قیمت ۲۶ کندل قبل است
   bool long_cond4 = chikou_value > ArrayMaximum(past_highs, 0, WHOLE_ARRAY); // فضای باز: چیکو بالاتر از تمام سقف‌های گذشته است
   if (long_cond1 && long_cond2 && long_cond3 && long_cond4)
   {
      LogSignal(symbol, "کنسی", "خرید"); // لاگ سیگنال
      return SIGNAL_LONG;
   }

   // شرط‌های فروش: breakout پایین ابر، ابر نزولی، چیکو پایین قیمت و فضای باز
   bool short_cond1 = close[0] < MathMin(ssa[0], ssb[0]) && close[1] >= MathMin(ssa[1], ssb[1]); // شرط breakout فروش
   bool short_cond2 = future_ssa[0] < future_ssb[0]; // ابر آینده نزولی است
   bool short_cond3 = chikou_value < chikou_compare_price[0]; // چیکو پایین‌تر از قیمت ۲۶ کندل قبل
   bool short_cond4 = chikou_value < ArrayMinimum(past_lows, 0, WHOLE_ARRAY); // فضای باز: چیکو پایین‌تر از تمام کف‌های گذشته
   if (short_cond1 && short_cond2 && short_cond3 && short_cond4)
   {
      LogSignal(symbol, "کنسی", "فروش");
      return SIGNAL_SHORT;
   }
   
   Log("بدون سیگنال در کنسی برای " + symbol); // اگر هیچ شرطی برقرار نبود
   return SIGNAL_NONE;
}

// تابع ManageKenseiExit: مدیریت خروج برای کنسی - به‌روزرسانی SL دینامیک
void ManageKenseiExit(ulong ticket, int ichi_handle)
{
   Log("شروع مدیریت خروج کنسی برای تیکت: " + IntegerToString(ticket));
   if (!PositionSelectByTicket(ticket)) { LogError("خطا در انتخاب پوزیشن برای خروج کنسی"); return; }
   
   string symbol = PositionGetString(POSITION_SYMBOL);
   long type = PositionGetInteger(POSITION_TYPE);
   
   // فقط برای خروج دینامیک این منطق اجرا می‌شود
   if (Inp_ExitLogic == EXIT_DYNAMIC)
   {
      if (ichi_handle == INVALID_HANDLE) { LogError("هندل ایچیموکو نامعتبر برای خروج در " + symbol); return; }
      
      double kijun[1];
      // گرفتن مقدار کیجون سن برای کندل قبلی
      if (CopyBuffer(ichi_handle, 1, 1, 1, kijun) <= 0) { LogError("خطا در کپی کیجون برای خروج در " + symbol); return; }
      
      double current_sl = PositionGetDouble(POSITION_SL); // SL فعلی پوزیشن
      double new_sl = kijun[0]; // SL جدید بر اساس کیجون
      
      bool modify = false; // فلگ برای اینکه آیا نیاز به تغییر هست یا نه
      
      // برای پوزیشن خرید، SL فقط باید بالا برود
      if (type == POSITION_TYPE_BUY && new_sl > current_sl) 
      {
         modify = true;
      }
      // برای پوزیشن فروش، SL فقط باید پایین بیاید (و صفر نباشد)
      else if (type == POSITION_TYPE_SELL && new_sl < current_sl && new_sl > 0) 
      {
         modify = true;
      }
      
      if (modify)
      {
         CTrade trade;
         // تغییر پوزیشن با SL جدید
         if (trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))
            Log("به‌روزرسانی SL دینامیک برای تیکت " + IntegerToString(ticket) + " به " + DoubleToString(new_sl, _Digits));
         else 
            LogError("خطا در تغییر SL دینامیک برای تیکت " + IntegerToString(ticket) + ": " + IntegerToString(trade.ResultRetcode()));
      }
      else
      {
         Log("تغییر SL دینامیک لازم نیست برای تیکت " + IntegerToString(ticket) + ". کیجون سن هنوز به حد مطلوب نرسیده.");
      }
   }
   else if (Inp_ExitLogic == EXIT_RRR)
   {
      // برای خروج RRR، حد سود و ضرر از قبل تنظیم شده و توسط سرور مدیریت می‌شود.
      // نیازی به اقدام در اینجا نیست.
      Log("خروج RRR برای کنسی فعال است. مدیریت توسط سرور انجام می‌شود. تیکت: " + IntegerToString(ticket));
   }
   
   Log("پایان مدیریت خروج کنسی برای تیکت: " + IntegerToString(ticket));
}

// پایان گارد
#endif

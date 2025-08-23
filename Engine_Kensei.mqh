// Engine_Kensei.mqh
// نسخه بازنویسی شده توسط سقراط (Socrates) طبق بلوپرینت Chimera V2.0
// این فایل به طور کامل بازنویسی شده تا خطای حیاتی در محاسبه "ابر آینده" را برطرف کرده و منطق را شفاف‌سازی کند.
// تمام توضیحات لازم برای درک فلسفه پشت هر بخش از کد، در کامنت‌ها گنجانده شده است.

// جلوگیری از تکرار تعریف هدر
#ifndef ENGINE_KENSEI_MQH
#define ENGINE_KENSEI_MQH

// اینکلود فایل‌های لازم
#include "Settings.mqh" // تنظیمات ورودی کاربر و ثابت‌های سیستم
#include "Logging.mqh"   // سیستم پیشرفته لاگینگ برای ثبت وقایع
#include "MoneyManagement.mqh" // برای دسترسی به enum سیگنال

//==================================================================================================
// تابع اصلی تولید سیگنال برای موتور کنسی (Kensei)
// این تابع بر اساس ۴ شرط طلایی ایچیموکو که در بلوپرینت مشخص شده، عمل می‌کند.
//==================================================================================================
SIGNAL GetKenseiSignal(string symbol, int ichi_handle, int atr_handle)
{
   // لاگ شروع عملیات برای پیگیری و دیباگینگ
   Log("شروع چک سیگنال کنسی برای نماد: " + symbol);

   // --- بخش ۱: اعتبارسنجی ورودی‌ها ---
   // قبل از هر کاری، مطمئن می‌شویم که ابزارهای لازم (هندل‌های اندیکاتور) معتبر هستند.
   if(ichi_handle == INVALID_HANDLE)
   {
      LogError("هندل ایچیموکو برای کنسی در نماد " + symbol + " نامعتبر است. سیگنال‌گیری متوقف شد.");
      return SIGNAL_NONE;
   }
   if(atr_handle == INVALID_HANDLE)
   {
      LogError("هندل ATR برای کنسی در نماد " + symbol + " نامعتبر است. سیگنال‌گیری متوقف شد.");
      return SIGNAL_NONE;
   }

   // --- بخش ۲: آماده‌سازی متغیرها و دریافت داده‌های کندل تثبیت‌شده (کندل ۱) ---
   // فلسفه اصلی: برای صدور سیگنال، ما همیشه از کندل "تثبیت‌شده" یا "بسته شده" قبلی (ایندکس ۱) استفاده می‌کنیم.
   // چون کندل فعلی (ایندکس ۰) هنوز در حال حرکت است و می‌تواند سیگنال کاذب تولید کند.
   // بنابراین، تمام داده‌های مربوط به شرایط سیگنال (شکست ابر، وضعیت چیکو) از کندل ۱ خوانده می‌شوند.

   // آرایه‌ها برای ذخیره داده‌های ایچیموکو از کندل ۱ و ۲ (برای تشخیص کراس)
   double tenkan[1], kijun[1], ssa[2], ssb[2];
   double close[2];
   double chikou_compare_price[1];
   double past_highs[];
   double past_lows[];

   // کپی داده‌های ایچیموکو برای کندل ۱ (و ۲ برای ابر)
   if(CopyBuffer(ichi_handle, 0, 1, 1, tenkan) <= 0) { LogError("کنسی: خطا در کپی تنکان برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(ichi_handle, 1, 1, 1, kijun) <= 0) { LogError("کنسی: خطا در کپی کیجون برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(ichi_handle, 2, 1, 2, ssa) <= 0) { LogError("کنسی: خطا در کپی SSA برای " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(ichi_handle, 3, 1, 2, ssb) <= 0) { LogError("کنسی: خطا در کپی SSB برای " + symbol); return SIGNAL_NONE; }

   // کپی قیمت بسته شدن برای کندل ۱ و ۲
   if(CopyClose(symbol, Inp_Kensei_Timeframe, 1, 2, close) < 2) { LogError("کنسی: خطا در کپی قیمت‌های بسته شدن برای " + symbol); return SIGNAL_NONE; }

   // --- بخش ۳: محاسبه صحیح "ابر آینده" (Future Kumo) ---
   // نکته حیاتی و دلیل اصلی بازنویسی: "ابر آینده" یک پیش‌بینی است که باید بر اساس جدیدترین اطلاعات موجود انجام شود.
   // جدیدترین اطلاعات همیشه در کندل ۰ (کندل فعلی که در حال تشکیل است) قرار دارد.
   // بنابراین، برخلاف سایر محاسبات، برای این یک شرط خاص، ما از دیتای کندل ۰ استفاده می‌کنیم.
   double future_ssa[1], future_ssb[1];
   double current_tenkan[1], current_kijun[1];

   // دریافت تنکان و کیجون از کندل فعلی (ایندکس ۰)
   if(CopyBuffer(ichi_handle, 0, 0, 1, current_tenkan) <= 0) { LogError("کنسی: خطا در کپی تنکان فعلی برای محاسبه ابر آینده در " + symbol); return SIGNAL_NONE; }
   if(CopyBuffer(ichi_handle, 1, 0, 1, current_kijun) <= 0) { LogError("کنسی: خطا در کپی کیجون فعلی برای محاسبه ابر آینده در " + symbol); return SIGNAL_NONE; }

   // محاسبه Senkou Span A آینده بر اساس تنکان و کیجون فعلی
   future_ssa[0] = (current_tenkan[0] + current_kijun[0]) / 2.0;

   // محاسبه Senkou Span B آینده بر اساس بالاترین سقف و پایین‌ترین کف در ۵۲ کندل اخیر (شامل کندل فعلی)
   double high52[52], low52[52];
   if(CopyHigh(symbol, Inp_Kensei_Timeframe, 0, 52, high52) != 52 || CopyLow(symbol, Inp_Kensei_Timeframe, 0, 52, low52) != 52)
   {
      LogError("کنسی: خطا در کپی High/Low برای محاسبه SSB آینده در " + symbol);
      return SIGNAL_NONE;
   }
   future_ssb[0] = (ArrayMaximum(high52, 0, WHOLE_ARRAY) + ArrayMinimum(low52, 0, WHOLE_ARRAY)) / 2.0;


   // --- بخش ۴: بررسی شرایط چهارگانه سیگنال ---
   // حالا که تمام داده‌های لازم (هم از کندل ۱ و هم محاسبه آینده از کندل ۰) را داریم، شروط را بررسی می‌کنیم.

   // **شرط اول: شکست ابر کومو (Kumo Breakout)**
   // قیمت در کندل ۱ باید بالای/پایین ابر باشد، در حالی که در کندل ۲ اینطور نبوده است. این یعنی "کراس".
   bool is_kumo_breakout_long = close[0] > MathMax(ssa[0], ssb[0]) && close[1] <= MathMax(ssa[1], ssb[1]);
   bool is_kumo_breakout_short = close[0] < MathMin(ssa[0], ssb[0]) && close[1] >= MathMin(ssa[1], ssb[1]);

   // **شرط دوم: تایید ابر آینده (Future Kumo Confirmation)**
   // ابر آینده که بر اساس دیتای کندل ۰ محاسبه شده، باید هم‌جهت با شکست باشد.
   bool is_future_kumo_bullish = future_ssa[0] > future_ssb[0];
   bool is_future_kumo_bearish = future_ssa[0] < future_ssb[0];

   // **شرط سوم: تایید چیکو اسپن (Chikou Span Confirmation)**
   // مقدار چیکو (که قیمت بسته شدن کندل ۱ است) باید بالاتر/پایین‌تر از قیمت ۲۶ کندل قبل از خودش باشد.
   double chikou_value = close[0];
   if(CopyClose(symbol, Inp_Kensei_Timeframe, 1 + Inp_Kensei_Kijun, 1, chikou_compare_price) < 1) { LogError("کنسی: خطا در کپی قیمت گذشته برای مقایسه چیکو در " + symbol); return SIGNAL_NONE; }
   bool is_chikou_confirm_long = chikou_value > chikou_compare_price[0];
   bool is_chikou_confirm_short = chikou_value < chikou_compare_price[0];

   // **شرط چهارم: فیلتر فضای باز چیکو (Chikou Open Space Filter)**
   // مسیر حرکت چیکو نباید با قیمت‌های اخیر مسدود شده باشد.
   if(CopyHigh(symbol, Inp_Kensei_Timeframe, 1 + Inp_Kensei_Kijun, Inp_Kensei_Chikou_OpenSpace, past_highs) != Inp_Kensei_Chikou_OpenSpace) { LogError("خطا در کپی High برای فضای باز چیکو در " + symbol); return SIGNAL_NONE; }
   if(CopyLow(symbol, Inp_Kensei_Timeframe, 1 + Inp_Kensei_Kijun, Inp_Kensei_Chikou_OpenSpace, past_lows) != Inp_Kensei_Chikou_OpenSpace) { LogError("خطا در کپی Low برای فضای باز چیکو در " + symbol); return SIGNAL_NONE; }
   bool is_chikou_open_space_long = chikou_value > ArrayMaximum(past_highs, 0, WHOLE_ARRAY);
   bool is_chikou_open_space_short = chikou_value < ArrayMinimum(past_lows, 0, WHOLE_ARRAY);

   // --- بخش ۵: تصمیم‌گیری نهایی ---
   // اگر تمام ۴ شرط برای خرید برقرار باشند، سیگنال خرید صادر می‌شود.
   if(is_kumo_breakout_long && is_future_kumo_bullish && is_chikou_confirm_long && is_chikou_open_space_long)
   {
      LogSignal(symbol, "کنسی", "خرید");
      return SIGNAL_LONG;
   }

   // اگر تمام ۴ شرط برای فروش برقرار باشند، سیگنال فروش صادر می‌شود.
   if(is_kumo_breakout_short && is_future_kumo_bearish && is_chikou_confirm_short && is_chikou_open_space_short)
   {
      LogSignal(symbol, "کنسی", "فروش");
      return SIGNAL_SHORT;
   }

   // اگر هیچ‌کدام از شرایط بالا برقرار نبود، هیچ سیگنالی وجود ندارد.
   Log("بدون سیگنال در کنسی برای " + symbol);
   return SIGNAL_NONE;
}


//==================================================================================================
// تابع مدیریت خروج برای معاملات باز موتور کنسی
// این تابع مسئولیت حد ضرر متحرک (Trailing Stop) را بر عهده دارد.
//==================================================================================================
void ManageKenseiExit(ulong ticket, int ichi_handle)
{
   // لاگ شروع عملیات برای پیگیری
   Log("شروع مدیریت خروج کنسی برای تیکت: " + IntegerToString(ticket));

   // انتخاب پوزیشن با تیکت داده شده برای دسترسی به اطلاعات آن
   if(!PositionSelectByTicket(ticket))
   {
      LogError("خطا در انتخاب پوزیشن برای خروج کنسی با تیکت: " + (string)ticket);
      return;
   }

   // این منطق فقط زمانی اجرا می‌شود که کاربر در تنظیمات، خروج "دینامیک" را انتخاب کرده باشد.
   if(Inp_ExitLogic == EXIT_DYNAMIC)
   {
      // دریافت اطلاعات لازم از پوزیشن باز
      string symbol = PositionGetString(POSITION_SYMBOL);
      long type = PositionGetInteger(POSITION_TYPE);

      // اعتبارسنجی هندل ایچیموکو
      if(ichi_handle == INVALID_HANDLE) { LogError("هندل ایچیموکو برای خروج دینامیک در " + symbol + " نامعتبر است."); return; }

      // دریافت مقدار کیجون-سن از کندل تثبیت‌شده قبلی (ایندکس ۱)
      double kijun[1];
      if(CopyBuffer(ichi_handle, 1, 1, 1, kijun) <= 0) { LogError("خطا در کپی کیجون برای خروج در " + symbol); return; }

      // دریافت حد ضرر فعلی پوزیشن
      double current_sl = PositionGetDouble(POSITION_SL);
      // حد ضرر جدید پیشنهادی بر اساس کیجون-سن
      double new_sl = kijun[0];

      bool modify_position = false; // یک پرچم برای اینکه آیا نیاز به تغییر پوزیشن هست یا نه

      // منطق حد ضرر متحرک:
      // برای یک معامله خرید (Long)، حد ضرر فقط باید به سمت بالا حرکت کند و هرگز پایین نمی‌آید.
      if(type == POSITION_TYPE_BUY && new_sl > current_sl)
      {
         modify_position = true;
      }
      // برای یک معامله فروش (Short)، حد ضرر فقط باید به سمت پایین حرکت کند.
      else if(type == POSITION_TYPE_SELL && new_sl < current_sl && new_sl > 0)
      {
         modify_position = true;
      }

      // اگر نیاز به تغییر حد ضرر بود
      if(modify_position)
      {
         Log("تلاش برای به‌روزرسانی SL دینامیک برای تیکت " + (string)ticket + " از " + DoubleToString(current_sl, _Digits) + " به " + DoubleToString(new_sl, _Digits));
         CTrade trade;
         // ارسال درخواست تغییر پوزیشن به سرور
         if(trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))
            Log("SL دینامیک برای تیکت " + (string)ticket + " با موفقیت به‌روزرسانی شد.");
         else
            LogError("خطا در تغییر SL دینامیک برای تیکت " + (string)ticket + ": " + (string)trade.ResultRetcode() + " - " + trade.ResultComment());
      }
   }
   // اگر منطق خروج بر اساس RRR باشد، هیچ کاری در اینجا انجام نمی‌شود.
   // چون حد سود و ضرر از ابتدا ثابت تنظیم شده و توسط سرور بروکر مدیریت می‌شود.
   else if(Inp_ExitLogic == EXIT_RRR)
   {
      Log("خروج RRR برای کنسی فعال است. مدیریت توسط سرور انجام می‌شود. تیکت: " + (string)ticket);
   }

   Log("پایان مدیریت خروج کنسی برای تیکت: " + (string)ticket);
}

// پایان گارد پیش‌پردازنده
#endif

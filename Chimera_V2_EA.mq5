// Chimera_V2_EA.mq5
// این فایل اصلی اکسپرت است که تمام اجزا را هماهنگ می‌کند. این اکسپرت برای متاتریدر ۵ بهینه‌سازی شده و از تایمر برای چک دوره‌ای استفاده می‌کند.
// سیستم دو موتور دارد: کنسی (تهاجمی، روندگیر) و هاپلیت (دفاعی، بازگشت به میانگین).
// تمام عملیات با لاگینگ دقیق همراه است تا برای دیباگینگ و آموزش مناسب باشد.
// برای مقاومت در برابر خطای انسانی، وزن‌ها نرمال‌سازی می‌شوند.

// مشخصات کپی‌رایت و نسخه برای شناسایی در متاتریدر
#property copyright "Chimera V2.0" // کپی‌رایت اکسپرت
#property version   "2.00" // نسخه اکسپرت - برای پیگیری به‌روزرسانی‌ها
#property strict // حالت strict: برای کامپایل دقیق و جلوگیری از اشتباهات قدیمی MQL4

// اینکلود فایل‌های هدر لازم - هر فایل مسئولیت خاصی دارد
#include "Settings.mqh" // تنظیمات ورودی کاربر و ثابت‌ها
#include "Logging.mqh" // سیستم لاگینگ برای ثبت رویدادها
#include "MoneyManagement.mqh" // مدیریت پول، ریسک و باز کردن معاملات
#include "Engine_Kensei.mqh" // موتور کنسی برای سیگنال‌های روند
#include "Engine_Hoplite.mqh" // موتور هاپلیت برای سیگنال‌های رنج

// متغیرهای جهانی - این‌ها در سراسر اکسپرت قابل دسترسی هستند
// آرایه‌ها برای نمادها و زمان‌های آخرین بار - برای تشخیص بار جدید
string kensei_syms[]; // آرایه نمادهای موتور کنسی - از ورودی کاربر پر می‌شود
datetime last_kensei_times[]; // آرایه زمان آخرین بار برای هر نماد کنسی - برای جلوگیری از پردازش تکراری
string hoplite_syms[]; // آرایه نمادهای موتور هاپلیت
datetime last_hoplite_times[]; // آرایه زمان آخرین بار برای هر نماد هاپلیت
// هندل‌های اندیکاتورها - برای دسترسی سریع به داده‌های اندیکاتور
int g_kensei_ichi_handles[]; // هندل‌های ایچیموکو برای کنسی - یکی برای هر نماد
int g_kensei_atr_handles[]; // هندل‌های ATR برای کنسی
int g_hoplite_bb_handles[]; // هندل‌های بولینگر برای هاپلیت
int g_hoplite_rsi_handles[]; // هندل‌های RSI برای هاپلیت
int g_hoplite_adx_handles[]; // هندل‌های ADX برای هاپلیت
int g_hoplite_atr_handles[]; // هندل‌های ATR برای هاپلیت
// متغیرهای جهانی برای تنظیمات نرمال‌شده - برای مدیریت خطای انسانی در ورودی‌ها
double g_Kensei_Weight; // وزن نرمال‌شده کنسی
double g_Hoplite_Weight; // وزن نرمال‌شده هاپلیت
bool g_Kensei_IsActive; // وضعیت فعال کنسی - ممکن است در نرمال‌سازی تغییر کند
bool g_Hoplite_IsActive; // وضعیت فعال هاپلیت

// تابع OnInit: راه‌اندازی اولیه اکسپرت - این تابع هنگام لود اکسپرت فراخوانی می‌شود
int OnInit()
{
   Log("شروع Chimera V2.0"); // لاگ شروع سیستم برای ثبت در فایل و ترمینال
   LogInit(); // راه‌اندازی سیستم لاگینگ - باز کردن فایل لاگ
   
   // تقسیم رشته نمادها به آرایه - برای پردازش چند نماد
   int kensei_count = StringSplit(Inp_Kensei_Symbols, ',', kensei_syms); // تقسیم نمادهای کنسی
   if (kensei_count <= 0) { LogError("خطا در تقسیم نمادهای کنسی: " + Inp_Kensei_Symbols); return INIT_FAILED; } // چک خطا و بازگشت شکست
   ArrayResize(last_kensei_times, kensei_count); // تنظیم اندازه آرایه زمان‌ها
   ArrayInitialize(last_kensei_times, 0); // مقداردهی اولیه به صفر (زمان نامعتبر)
   
   int hoplite_count = StringSplit(Inp_Hoplite_Symbols, ',', hoplite_syms); // تقسیم نمادهای هاپلیت
   if (hoplite_count <= 0) { LogError("خطا در تقسیم نمادهای هاپلیت: " + Inp_Hoplite_Symbols); return INIT_FAILED; } // چک خطا
   ArrayResize(last_hoplite_times, hoplite_count); // تنظیم اندازه
   ArrayInitialize(last_hoplite_times, 0); // مقداردهی اولیه
   
   // --- مقاوم‌سازی در برابر خطای انسانی: نرمال‌سازی وزن‌ها ---
   // این بخش وزن‌ها را چک و نرمال می‌کند تا مجموع همیشه ۱.۰ باشد
   g_Kensei_Weight = Inp_Kensei_Weight; // مقدار اولیه از ورودی
   g_Hoplite_Weight = Inp_Hoplite_Weight; // مقدار اولیه
   g_Kensei_IsActive = Inp_Kensei_IsActive; // وضعیت اولیه
   g_Hoplite_IsActive = Inp_Hoplite_IsActive; // وضعیت اولیه
   double total_weight = g_Kensei_Weight + g_Hoplite_Weight; // محاسبه مجموع
   if (total_weight <= 0) // اگر مجموع نامعتبر (صفر یا منفی)
   {
      LogError("مجموع وزن‌های تخصیص یافته صفر یا منفی است. موتورها غیرفعال می‌شوند."); // لاگ خطا
      g_Kensei_IsActive = false; // غیرفعال کردن موتورها
      g_Hoplite_IsActive = false; // غیرفعال کردن
   }
   else if (total_weight != 1.0) // اگر مجموع دقیقاً ۱.۰ نیست (برای جلوگیری از ریسک بیش از حد)
   {
      Log("هشدار: مجموع وزن‌ها (" + DoubleToString(total_weight, 2) + ") برابر با ۱.۰ نیست. نرمال‌سازی انجام می‌شود."); // لاگ هشدار
      // نرمال‌سازی: تقسیم هر وزن بر مجموع برای حفظ نسبت
      g_Kensei_Weight = g_Kensei_Weight / total_weight; // وزن جدید کنسی
      g_Hoplite_Weight = g_Hoplite_Weight / total_weight; // وزن جدید هاپلیت
      Log("وزن جدید کنسی: " + DoubleToString(g_Kensei_Weight, 2) + ", وزن جدید هاپلیت: " + DoubleToString(g_Hoplite_Weight, 2)); // لاگ وزن‌های جدید
   }
   // --- پایان نرمال‌سازی وزن‌ها ---
   
   // ایجاد هندل‌های اندیکاتور برای کنسی
   ArrayResize(g_kensei_ichi_handles, kensei_count); // تنظیم اندازه آرایه هندل‌ها
   ArrayResize(g_kensei_atr_handles, kensei_count); // تنظیم اندازه
   for (int i = 0; i < kensei_count; i++) // حلقه برای هر نماد
   {
      g_kensei_ichi_handles[i] = iIchimoku(kensei_syms[i], Inp_Kensei_Timeframe, Inp_Kensei_Tenkan, Inp_Kensei_Kijun, Inp_Kensei_SenkouB); // ایجاد هندل ایچیموکو
      g_kensei_atr_handles[i] = iATR(kensei_syms[i], Inp_Kensei_Timeframe, Inp_Kensei_ATR_Period); // ایجاد هندل ATR
      if (g_kensei_ichi_handles[i] == INVALID_HANDLE || g_kensei_atr_handles[i] == INVALID_HANDLE) // چک هندل نامعتبر
      {
         LogError("خطا در ایجاد هندل کنسی برای نماد: " + kensei_syms[i]); // لاگ خطا
         return INIT_FAILED; // بازگشت با شکست ابتدایی
      }
   }
   
   // ایجاد هندل‌های اندیکاتور برای هاپلیت
   ArrayResize(g_hoplite_bb_handles, hoplite_count); // تنظیم اندازه
   ArrayResize(g_hoplite_rsi_handles, hoplite_count); // تنظیم اندازه
   ArrayResize(g_hoplite_adx_handles, hoplite_count); // تنظیم اندازه
   ArrayResize(g_hoplite_atr_handles, hoplite_count); // تنظیم اندازه
   for (int i = 0; i < hoplite_count; i++) // حلقه برای هر نماد
   {
      g_hoplite_bb_handles[i] = iBands(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_BB_Period, 0, Inp_Hoplite_BB_Deviation, PRICE_CLOSE); // ایجاد هندل بولینگر
      g_hoplite_rsi_handles[i] = iRSI(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_RSI_Period, PRICE_CLOSE); // ایجاد هندل RSI
      g_hoplite_adx_handles[i] = iADX(hoplite_syms[i], Inp_Hoplite_Timeframe, Inp_Hoplite_ADX_Period); // ایجاد هندل ADX
      g_hoplite_atr_handles[i] = iATR(hoplite_syms[i], Inp_Hoplite_Timeframe, 14); // ایجاد هندل ATR (دوره ثابت ۱۴)
      if (g_hoplite_bb_handles[i] == INVALID_HANDLE || g_hoplite_rsi_handles[i] == INVALID_HANDLE || 
          g_hoplite_adx_handles[i] == INVALID_HANDLE || g_hoplite_atr_handles[i] == INVALID_HANDLE) // چک هندل نامعتبر
      {
         LogError("خطا در ایجاد هندل هاپلیت برای نماد: " + hoplite_syms[i]); // لاگ خطا
         return INIT_FAILED; // بازگشت شکست
      }
   }
   
   // نمایش اندیکاتورها روی چارت اگر فعال باشد - فقط برای نماد فعلی چارت
   if (Inp_Show_Kensei_Indicators) // چک گزینه نمایش کنسی
   {
      iIchimoku(_Symbol, Inp_Kensei_Timeframe, Inp_Kensei_Tenkan, Inp_Kensei_Kijun, Inp_Kensei_SenkouB); // نمایش ایچیموکو
      Log("اندیکاتورهای کنسی نمایش داده شد"); // لاگ نمایش
   }
   if (Inp_Show_Hoplite_Indicators) // چک گزینه نمایش هاپلیت
   {
      iBands(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_BB_Period, 0, Inp_Hoplite_BB_Deviation, PRICE_CLOSE); // نمایش بولینگر
      iRSI(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_RSI_Period, PRICE_CLOSE); // نمایش RSI
      iADX(_Symbol, Inp_Hoplite_Timeframe, Inp_Hoplite_ADX_Period); // نمایش ADX
      Log("اندیکاتورهای هاپلیت نمایش داده شد"); // لاگ نمایش
   }
   if (Inp_Show_OnChart_Display) // چک نمایش پنل
   {
      Log("پنل اطلاعات روی چارت نمایش داده شد"); // لاگ نمایش (پنل واقعی باید پیاده شود اگر لازم)
   }
   g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY); // تنظیم اوج اکویتی اولیه برای محاسبه افت
   Log("اوج اکویتی اولیه تنظیم شد: " + DoubleToString(g_peak_equity, 2)); // لاگ مقدار
   EventSetTimer(1); // تنظیم تایمر هر ۱ ثانیه برای چک دوره‌ای - بهینه برای متاتریدر
   return(INIT_SUCCEEDED); // بازگشت موفق ابتدایی
}

// تابع OnDeinit: خاموش کردن اکسپرت - هنگام unload فراخوانی می‌شود
void OnDeinit(const int reason)
{
   Log("توقف Chimera V2.0 با دلیل: " + IntegerToString(reason)); // لاگ دلیل توقف (reason کد متاتریدر است)
   EventKillTimer(); // خاموش کردن تایمر برای جلوگیری از فراخوانی OnTimer
   // آزاد کردن هندل‌های اندیکاتور برای مدیریت حافظه
   for (int i = 0; i < ArraySize(g_kensei_ichi_handles); i++) // حلقه برای کنسی
   {
      if (g_kensei_ichi_handles[i] != INVALID_HANDLE) IndicatorRelease(g_kensei_ichi_handles[i]); // آزاد کردن ایچیموکو
      if (g_kensei_atr_handles[i] != INVALID_HANDLE) IndicatorRelease(g_kensei_atr_handles[i]); // آزاد کردن ATR
   }
   for (int i = 0; i < ArraySize(g_hoplite_bb_handles); i++) // حلقه برای هاپلیت
   {
      if (g_hoplite_bb_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_bb_handles[i]); // آزاد کردن بولینگر
      if (g_hoplite_rsi_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_rsi_handles[i]); // آزاد کردن RSI
      if (g_hoplite_adx_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_adx_handles[i]); // آزاد کردن ADX
      if (g_hoplite_atr_handles[i] != INVALID_HANDLE) IndicatorRelease(g_hoplite_atr_handles[i]); // آزاد کردن ATR
   }
   LogDeinit(); // خاموش کردن لاگینگ - بستن فایل
}

// تابع OnTimer: چک دوره‌ای هر ۱ ثانیه - برای تشخیص بار جدید و مدیریت
void OnTimer()
{
   Log("چک تایمر - ارزیابی پورتفولیو و سیگنال‌ها"); // لاگ هر چک برای پیگیری عملکرد
   if (IsPortfolioDrawdownExceeded()) // چک افت سرمایه بیش از حد
   {
      Log("افت سرمایه بیش از حد تشخیص داده شد - بستن تمام پوزیشن‌ها"); // لاگ اقدام اضطراری
      CloseAllPositions(); // بستن تمام پوزیشن‌ها برای حفاظت سرمایه
      return; // بازگشت زود برای جلوگیری از باز کردن معاملات جدید
   }
   if (g_Kensei_IsActive) // چک فعال بودن کنسی (پس از نرمال‌سازی)
   {
      for (int i = 0; i < ArraySize(kensei_syms); i++) // حلقه برای هر نماد کنسی
      {
         datetime current_time = iTime(kensei_syms[i], Inp_Kensei_Timeframe, 0); // زمان بار فعلی
         if (current_time > last_kensei_times[i]) // اگر بار جدید (برای جلوگیری از پردازش تکراری)
         {
            Log("بار جدید در تایم‌فریم کنسی برای نماد " + kensei_syms[i]); // لاگ بار جدید
            last_kensei_times[i] = current_time; // به‌روزرسانی زمان
            SIGNAL sig = GetKenseiSignal(kensei_syms[i], g_kensei_ichi_handles[i], g_kensei_atr_handles[i]); // گرفتن سیگنال
            OpenTrade(kensei_syms[i], sig, 1, g_kensei_atr_handles[i]); // باز کردن معامله اگر سیگنال باشد
         }
      }
   }
   if (g_Hoplite_IsActive) // چک فعال بودن هاپلیت
   {
      for (int i = 0; i < ArraySize(hoplite_syms); i++) // حلقه برای هر نماد
      {
         datetime current_time = iTime(hoplite_syms[i], Inp_Hoplite_Timeframe, 0); // زمان بار فعلی
         if (current_time > last_hoplite_times[i]) // بار جدید
         {
            Log("بار جدید در تایم‌فریم هاپلیت برای نماد " + hoplite_syms[i]); // لاگ
            last_hoplite_times[i] = current_time; // به‌روزرسانی
            SIGNAL sig = GetHopliteSignal(hoplite_syms[i], g_hoplite_bb_handles[i], g_hoplite_rsi_handles[i], g_hoplite_adx_handles[i]); // سیگنال
            OpenTrade(hoplite_syms[i], sig, 2, g_hoplite_atr_handles[i]); // باز کردن
         }
      }
   }
   ManageTrades(); // مدیریت پوزیشن‌های باز - چک خروج
}

// تابع ManageTrades: مدیریت پوزیشن‌های باز - چک شرایط خروج برای هر موتور
void ManageTrades()
{
   Log("شروع مدیریت معاملات باز"); // لاگ شروع
   for (int i = PositionsTotal() - 1; i >= 0; i--) // حلقه از آخرین پوزیشن (برای جلوگیری از مشکلات ایندکس)
   {
      ulong ticket = PositionGetTicket(i); // گرفتن تیکت
      if (ticket == 0) continue; // اگر نامعتبر، رد شود
      ulong magic = PositionGetInteger(POSITION_MAGIC); // شماره جادویی برای شناسایی موتور
      string symbol = PositionGetString(POSITION_SYMBOL); // نماد پوزیشن
      if (magic == Inp_BaseMagicNumber + 1) // اگر کنسی
      {
         int sym_index = -1; // جستجو برای ایندکس نماد
         for (int j = 0; j < ArraySize(kensei_syms); j++)
         {
            if (kensei_syms[j] == symbol) { sym_index = j; break; } // پیدا کردن ایندکس
         }
         if (sym_index != -1) // اگر پیدا شد
         {
            ManageKenseiExit(ticket, g_kensei_ichi_handles[sym_index]); // مدیریت خروج کنسی
         }
         else // اگر نه
         {
            LogError("نماد " + symbol + " در لیست کنسی برای تیکت " + IntegerToString(ticket) + " پیدا نشد"); // لاگ خطا
         }
      }
      else if (magic == Inp_BaseMagicNumber + 2) // اگر هاپلیت
      {
         int sym_index = -1;
         for (int j = 0; j < ArraySize(hoplite_syms); j++)
         {
            if (hoplite_syms[j] == symbol) { sym_index = j; break; }
         }
         if (sym_index != -1)
         {
            ManageHopliteExit(ticket, g_hoplite_bb_handles[sym_index]); // مدیریت خروج هاپلیت
         }
         else
         {
            LogError("نماد " + symbol + " در لیست هاپلیت برای تیکت " + IntegerToString(ticket) + " پیدا نشد"); // لاگ خطا
         }
      }
   }
   Log("پایان مدیریت معاملات"); // لاگ پایان
}

// تابع CloseAllPositions: بستن تمام پوزیشن‌ها در شرایط اضطراری مانند افت بیش از حد
void CloseAllPositions()
{
   Log("شروع بستن تمام پوزیشن‌ها"); // لاگ شروع
   CTrade trade; // شیء تجارت برای عملیات بستن
   for (int i = PositionsTotal() - 1; i >= 0; i--) // حلقه از آخرین
   {
      ulong ticket = PositionGetTicket(i); // تیکت
      if (ticket == 0) continue; // رد نامعتبر
      string symbol = PositionGetString(POSITION_SYMBOL); // نماد
      long type = PositionGetInteger(POSITION_TYPE); // نوع (خرید/فروش)
      double close_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت بسته شدن
      if (trade.PositionClose(ticket, 3)) // سعی در بستن با slippage 3
         LogCloseTrade(ticket, "افت سرمایه بیش از حد"); // لاگ موفق
      else
         LogError("خطا در بستن پوزیشن تیکت " + IntegerToString(ticket) + ": " + IntegerToString(trade.ResultRetcode())); // لاگ خطا
   }
   Log("پایان بستن پوزیشن‌ها"); // لاگ پایان
}
